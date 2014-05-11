#!/usr/bin/env ruby

require 'open-uri'
require 'nokogiri'
require 'cgi'

module FeedPull

  TorrentSource = Struct.new :id, :name, :source

  def self.pull decoder, source
    self.send :"#{decoder}_pull", source
  end

  def self.scrape_pull uri
    dom = Nokogiri::HTML open(uri)
    dom.css('tr.forum_header_border').map do |row|
      link = row.css('a.magnet').first
      link ? magnet_source(link['href']) : nil
    end.compact.reverse
  end

  private

  def self.magnet_source magnet_uri
    raise "not a magnet URI: #{magnet_uri}" unless magnet_uri =~ /^magnet:\?/
    values = CGI.parse magnet_uri.split('?', 2)[1]
    raise "magnet URI does not have an identifier! #{magnet_uri}" unless values['xt']
    id = values['xt'].join ','
    name = values['dn'] ? CGI.unescape(values['dn'].join(',')) : nil
    TorrentSource.new "magnet:#{id}", name, magnet_uri
  end

end
