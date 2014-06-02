class TorrentFile < Sequel::Model
  
  unrestrict_primary_key
  many_to_one :torrent

  def full_path
    return nil unless torrent_dir = torrent.download_dir
    File.join torrent_dir, name
  end

end