Sequel.migration do

  change do

    alter_table :torrents do
      add_column :download_dir, String
    end

  end

end
