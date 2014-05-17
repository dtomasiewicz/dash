Sequel.migration do

  change do

    create_table :torrent_files do
      foreign_key :torrent_id, :torrents, type: String, null: false
      String :name, null: false
      TrueClass :complete, null: false
      primary_key [:torrent_id, :name]
    end

  end

end
