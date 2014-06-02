class Torrent < Sequel::Model

  STATE_DOWNLOADING = 'DOWNLOADING'
  STATE_COMPLETE = 'COMPLETE'
  STATE_SKIPPED = 'SKIPPED'
  STATE_MISSING = 'MISSING'

  ID_MAGNET_URN = 'MAGNET_URN'
  ID_TRANSMISSION_HASH = 'TRANSMISSION_HASH'

  unrestrict_primary_key
  one_to_many :feed_torrents
  one_to_many :torrent_files
  many_to_many :feeds, join_table: :feed_torrents

  def before_destroy
    feed_torrents.each &:destroy
    torrent_files.each &:destroy
  end

end