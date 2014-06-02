get '/torrents/:id' do
  if torrent = Torrent[unescape params[:id]]
    erb :torrent, locals: {torrent: torrent}
  end
end

post '/torrents/:id/start' do
  if torrent = Torrent[unescape params[:id]]
    puts "STARTING #{torrent.id}"
    if info = TORRENTD.client.add_torrent(torrent.source)
      torrent.name = info['name']
      torrent.transmission_hash = info['hashString']
      torrent.state = Torrent::STATE_DOWNLOADING
      torrent.save_changes
    end
    redirect to("/torrents/#{torrent.id}")
  else
    raise "Torrent doesn't exist!"
  end
end