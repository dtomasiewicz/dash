CREATE TABLE feeds (
	id string NOT NULL,
	source string NOT NULL,
	decoder varchar NOT NULL,
	PRIMARY KEY (id)
);
CREATE TABLE torrents (
	id string NOT NULL,
	added_at integer NOT NULL,
	state string NOT NULL,
	name string,
	source string,
	transmission_hash string,
	PRIMARY KEY (id),
	UNIQUE (transmission_hash)
);
CREATE TABLE feed_torrents (
	feed_id string NOT NULL,
	torrent_id string NOT NULL,
	PRIMARY KEY (feed_id, torrent_id),
	FOREIGN KEY (feed_id) REFERENCES feeds(id),
	FOREIGN KEY (torrent_id) REFERENCES torrents(id)
);