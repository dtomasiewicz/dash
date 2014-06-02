get '/feeds' do
  feeds = Feed.all
  recents = Torrent.where("datetime(added_at, 'unixepoch') > datetime('now', '-6 day')").
                    where("state != ?", Torrent::STATE_SKIPPED).
                    order(Sequel.desc :added_at).all
  erb :feeds, locals: {feeds: feeds, recents: recents}
end

get '/feeds/:id' do
  feed = Feed[params[:id]]
  torrents = feed.torrents
  erb :feed, locals: {feed: feed, torrents: torrents}
end

post '/feeds' do
  feed = Feed.new params
  # skip all existing items when a new feed is added
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