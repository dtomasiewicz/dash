class FeedTorrent < Sequel::Model

  unrestrict_primary_key
  many_to_one :feed
  many_to_one :torrent

end