require 'open-uri'
require 'nokogiri'
require 'cgi'

class Feed < Sequel::Model

  Item = Struct.new :id, :name, :source

  one_to_many :feed_torrents
  many_to_many :torrents, join_table: :feed_torrents

  def before_destroy
    feed_torrents.each &:destroy
  end

  def fetch
    send :"#{decoder}_pull", source
  end

  private

  def scrape_pull(uri)
    dom = Nokogiri::HTML open(uri)
    self.id = dom.css('td.section_post_header b').first.text if !id
    dom.css('tr.forum_header_border').map do |row|
      link = row.css('a.magnet').first
      link ? magnet_source(link['href']) : nil
    end.compact.reverse
  end

  def magnet_source(magnet_uri)
    raise "not a magnet URI: #{magnet_uri}" unless magnet_uri =~ /^magnet:\?/
    values = CGI.parse magnet_uri.split('?', 2)[1]
    raise "magnet URI does not have an identifier! #{magnet_uri}" unless values['xt']
    id = values['xt'].join ','
    name = values['dn'] ? CGI.unescape(values['dn'].join(',')) : nil
    Item.new "magnet:#{id}", name, magnet_uri
  end

end