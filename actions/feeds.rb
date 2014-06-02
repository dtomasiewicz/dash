get '/feeds' do
  feeds = Feed.all
  recents = Torrent.where("datetime(added_at, 'unixepoch') > datetime('now', '-6 day')").
                    where("state != ?", Torrent::STATE_SKIPPED).
                    order(Sequel.desc :added_at).all
  erb :feeds, locals: {feeds: feeds, recents: recents}
end

post '/feeds' do
  feed = Feed.new params
  # skip all existing items when a new feed is added
  items = feed.fetch
  torrent_ids = Set.new
  DB.transaction do
    feed.save
    items.each do |item|
      torrent = Torrent.find_or_create(id: item.id) do |t|
        t.name = item.name
        t.source = item.source
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

delete '/feeds/:id' do
  Feed[unescape params[:id]].destroy
  redirect to('/feeds')
end

post '/feeds/pull' do
  TORRENTD.pull_now
  redirect to(unescape params[:return_to])
end

get '/feeds/:id' do
  feed = Feed[unescape params[:id]]
  # TODO order torrents by the primary key of FeedTorrent
  torrents = feed.torrents
  erb :feed, locals: {feed: feed, torrents: torrents}
end

post '/feeds/:id/scrape' do
  scrape Feed[unescape params[:id]]
  redirect to('/feeds')
end