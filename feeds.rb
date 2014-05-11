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
      $stderr.puts e.inspect
      $stderr.puts e.backtrace
    end
  end
end

# feed scraping daemon
Thread.new do 
  loop do
    begin
      feeds = Feed.all
      start = Time.now
      puts "UPDATE AT #{start} (#{feeds.map(&:id).join ', '})"
      feeds.each do |feed|
        begin
          scrape feed
        rescue => e
          $stderr.puts e.inspect
          $stderr.puts e.backtrace
        end
      end
      last_update = Time.now
      puts "UPDATE COMPLETED IN #{last_update - start}"
      # TODO check for completion, update names, enqueue transcodes
      sleep 15*60
    rescue => e
      puts e.inspect
      puts e.backtrace
    end
  end
end
