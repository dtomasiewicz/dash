# transmission client
require_relative 'transmission'
TRANSMISSION = Transmission::Client.new CONFIG['transmission']

last_update = nil

get '/feeds' do
  feeds = Feed.all
  recents = Torrent.where("datetime(added_at, 'unixepoch') > datetime('now', '-6 day')").
                    where("state != ?", Torrent::STATE_SKIPPED).
                    order(Sequel.desc :added_at).all
  erb :feeds, locals: {feeds: feeds, recents: recents, last_update: last_update}
end

get '/feeds/:id' do
  feed = Feed[params[:id]]
  torrents = feed.torrents
  erb :feed, locals: {feed: feed, torrents: torrents}
end

post '/feeds' do
  feed = Feed.new params
  # fetch and skip all
  tsources = feed.fetch
  torrent_ids = Set.new
  DB.transaction do
    feed.save
    tsources.each do |tsource|
      torrent = Torrent.find_or_create(id: tsource.id) do |t|
        t.name = tsource.name
        t.source = tsource.source
        t.added_at = Time.now.to_i
        t.state = Torrent::STATE_SKIPPED
      end
      unless torrent_ids.include? torrent.id
        feed.add_feed_torrent torrent_id: torrent.id
        torrent_ids << torrent.id
      end
    end
  end
  redirect to('/feeds')
end

post '/feeds/scrape' do
  scrape Feed[params[:id]]
  redirect to('/feeds')
end

delete '/feeds' do
  Feed[params[:id]].destroy
  redirect to('/feeds')
end

def scrape feed
  puts "SCRAPING #{feed.id}:"
  existing = Set.new feed.feed_torrents_dataset.select_map(:torrent_id)
  feed.fetch.each do |tsource|
    next if existing.include? tsource.id
    begin
      info = TRANSMISSION.add_torrent tsource.source
      puts "  New torrent: #{info['name']}"
      torrent = Torrent.find_or_create(transmission_hash: info['hashString']) do |t|
        t.id = tsource.id
        t.name = info['name'] || tsource.name
        t.source = tsource.source
        t.added_at = Time.now.to_i
        t.state = Torrent::STATE_DOWNLOADING
      end
      torrent.add_feed_torrent feed_id: feed.id
      existing << torrent.id
    rescue => e
      puts e.inspect
      puts e.backtrace
    end
  end
end

def scrape_all_feeds
  feeds = Feed.all
  start = Time.now
  puts "UPDATE AT #{start} (#{feeds.map(&:id).join ', '})"
  feeds.each do |feed|
    begin
      scrape feed
    rescue => e
      puts e.inspect
      puts e.backtrace
    end
  end
  last_update = Time.now
  puts "UPDATE COMPLETED IN #{last_update - start}"
end

def update_torrents
  torrents = Torrent.where state: Torrent::STATE_DOWNLOADING
  infos = TRANSMISSION.get_torrents(['hashString', 'downloadDir', 'files'], torrents.map(&:transmission_hash)).map do |info|
    [info['hashString'], info]
  end

  newly_completed = []

  DB.transaction do
    torrents.each do |torrent|
      if info = infos[torrent.transmission_hash]
        files = Hash[torrent.files.map{|f| [f.name, f]}]
        info['files'].each do |file_info|
          complete = file_info['bytesCompleted'] == file_info['length']
          if file = files[file_info['name']]
            already_complete = file.complete
            file.complete = complete
            file.save_changes
          else
            already_complete = false
            torrent.add_torrent_file name: file_info['name'], complete: complete
          end
          if complete && !already_complete
            newly_completed << File.join(info['downloadDir'], file_info['name'])
          end
        end
      else
        torrent.state = Torrent::STATE_COMPLETE
      end
      torrent.save_changes
    end
  end

  newly_completed
end

def transcode file
  # TODO
end

# Torrent scraping/queueing daemon. Scrapes every 10 minutes, updates status
# every minute.
Thread.new do 
  skip_scrape = 0
  loop do
    begin
      if skip_scrape == 0
        scrape_all_feeds
        skip_scrape = 9
      end
      update_torrents.each{|f| transcode f}
    rescue => e
      puts e.inspect
      puts e.backtrace
    end
    sleep 60
    skip_scrape -= 1
  end
end
