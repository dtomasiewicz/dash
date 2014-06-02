class TorrentDaemon

  attr_reader :client, :last_pull, :last_update

  Event = Struct.new :time, :proc

  def initialize(client)
    @client = client
    @last_pull = @last_update = nil
    @events = []
    @on_file_complete = nil
  end

  def start(update_interval, pull_interval, sleep_seconds = 5)
    repeat(update_interval){update_all}
    repeat(pull_interval){pull_all}
    loop do
      begin
        step
      rescue => e
        puts e.inspect
        puts e.backtrace
      end
      sleep sleep_seconds
    end
  end

  def step
    @events.shift.proc.call until @events.empty? || @events.first.time > Time.now
  end

  def on_file_complete(&block)
    @on_file_complete = block
  end

  def update_now
    schedule{update_all}
  end

  def pull_now
    schedule{pull_all}
  end

  private

  def schedule(time = Time.now, &block)
    event = Event.new time, block
    i = 0
    i += 1 while i < @events.length && @events[i].time <= time
    @events.insert i, event
  end

  def repeat(interval, initial = Time.now, &block)
    repeater = proc{block.call; schedule Time.now+interval, &block}
    schedule initial, &repeater
  end

  def pull_all
    feeds = Feed.all
    @last_pull = timed "PULL_ALL (#{feeds.map(&:id).join ', '})" do
      feeds.each do |feed|
        begin
          pull feed
        rescue => e
          puts e.inspect
          puts e.backtrace
        end
      end
    end
  end

  def update_all
    torrents = Torrent.where state: Torrent::STATE_DOWNLOADING
    hashes = torrents.map &:transmission_hash

    @last_update = timed "UPDATE_ALL (#{hashes.join ', '})" do
      infos = Hash[@client.get_torrents(['hashString', 'downloadDir', 'files'], hashes).map do |info|
        [info['hashString'], info]
      end]

      DB.transaction do
        torrents.each do |torrent|
          if info = infos[torrent.transmission_hash]
            update_torrent_with_info torrent, info
          else
            torrent.state = Torrent::STATE_MISSING
          end
          torrent.save_changes
        end
      end
    end
  end

  def pull(feed)
    puts "PULLING #{feed.id}"
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

  def timed(desc, &block)
    puts "#{begin_time = Time.now}: BEGIN #{desc}"
    block.call
    puts "#{end_time = Time.now}: END #{desc} (#{end_time - begin_time})"
    end_time
  end

  def update_torrent_with_info(torrent, info)
    torrent.download_dir = info['downloadDir']
    return if info['files'].empty? # file list not yet downloaded

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
        file = torrent.add_torrent_file name: file_info['name'], complete: complete
      end
      schedule{@on_file_complete.call file if @on_file_complete} if complete && !already_complete
    end
    torrent.state = Torrent::STATE_COMPLETE if all_complete
  end

end