class TorrentDaemon

  attr_reader :client, :last_update

  def initialize(client)
    @client = client
    @last_update = nil
  end

  def on_file_complete(&block)
    @on_file_complete = block
  end

  # TODO pass in frequency as arguments
  def start
    skip_scrape = 0
    loop do
      begin
        if skip_scrape == 0
          scrape_all_feeds
          skip_scrape = 9
        end
        update_downloading_torrents
      rescue => e
        puts e.inspect
        puts e.backtrace
      end
      sleep 60
      skip_scrape -= 1
    end
  end

  private

  def scrape feed
    puts "SCRAPING #{feed.id}:"
    existing = Set.new feed.feed_torrents_dataset.select_map(:torrent_id)
    feed.fetch.each do |tsource|
      next if existing.include? tsource.id
      begin
        info = @client.add_torrent tsource.source
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
    @last_update = Time.now
    puts "UPDATE COMPLETED IN #{@last_update - start}"
  end

  def update_downloading_torrents
    torrents = Torrent.where state: Torrent::STATE_DOWNLOADING
    hashes = torrents.map &:transmission_hash
    puts "pulling torrent info for #{hashes}"
    infos = Hash[@client.get_torrents(['hashString', 'downloadDir', 'files'], hashes).map do |info|
      puts "PULLED TORRENT INFO: #{info}"
      [info['hashString'], info]
    end]

    new_files = []

    DB.transaction do
      torrents.each do |torrent|
        if info = infos[torrent.transmission_hash]
          torrent.download_dir = info['downloadDir']
          files = Hash[torrent.torrent_files.map{|f| [f.name, f]}]
          all_complete = true
          info['files'].each do |file_info|
            all_complete = false unless complete = file_info['bytesCompleted'] == file_info['length']
            if file = files[file_info['name']]
              already_complete = file.complete
              file.complete = complete
              file.save_changes
            else
              already_complete = false
              torrent.add_torrent_file name: file_info['name'], complete: complete
            end
            if complete && !already_complete
              new_files << file
            end
          end
          torrent.state = Torrent::STATE_COMPLETE if all_complete
        else
          torrent.state = Torrent::STATE_MISSING
        end
        torrent.save_changes
      end
    end

    new_files.each{|f| @on_file_complete.call f} if @on_file_complete
  end

end