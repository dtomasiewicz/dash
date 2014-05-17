require_relative 'feedpull'

class Feed < Sequel::Model

  unrestrict_primary_key
  one_to_many :feed_torrents
  many_to_many :torrents, join_table: :feed_torrents

  def fetch
    FeedPull.pull decoder, source
  end

  def before_destroy
    feed_torrents.each &:destroy
  end

end

class Torrent < Sequel::Model

  STATE_DOWNLOADING = 'DOWNLOADING'
  STATE_TRANSCODING = 'TRANSCODING'
  STATE_COMPLETE = 'COMPLETE'
  STATE_SKIPPED = 'SKIPPED'

  ID_MAGNET_URN = 'MAGNET_URN'
  ID_TRANSMISSION_HASH = 'TRANSMISSION_HASH'

  unrestrict_primary_key
  one_to_many :feed_torrents
  one_to_many :torrent_files
  many_to_many :feeds, join_table: :feed_torrents

  def before_destroy
    feed_torrents.each &:destroy
  end

end

class FeedTorrent < Sequel::Model

  unrestrict_primary_key
  many_to_one :feed
  many_to_one :torrent

end

class TorrentFiles < Sequel::Model
  
  unrestrict_primary_key
  many_to_one :torrent

end
