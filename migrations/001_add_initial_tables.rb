Sequel.migration do
  
  change do

    create_table :feeds do
      String :id, null: false, primary_key: true
      String :source, null: false
      String :decoder, null: false
    end

    create_table :torrents do
      # not keying off hashString :so that we can have skipped torrents
      String :id, null: false, primary_key: true
      Integer :added_at, null: false
      String :state, null: false
      String :name
      String :source
      String :transmission_hash, unique: true
    end

    create_table :feed_torrents do
      foreign_key :feed_id, :feeds, null: false
      foreign_key :torrent_id, :torrents, null: false
      primary_key [:feed_id, :torrent_id]
    end

  end

end
