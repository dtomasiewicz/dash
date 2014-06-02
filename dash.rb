#!/usr/bin/env ruby

require 'sinatra'
require 'sequel'
require 'erubis'
require 'yaml'

CONFIG = YAML.load_file 'config.yml'

# rack setup
use Rack::MethodOverride
use Rack::Auth::Basic, "Restricted Area" do |username, password|
  username == CONFIG['username'] && password == CONFIG['password']
end

# sinatra setup
set :environment, :production
set :erb, escape_html: true

# database setup
DB = Sequel.sqlite CONFIG['database']
%w{feed torrent feed_torrent torrent_file}.each do |m|
  require_relative "models/#{m}"
end

# actions
require_relative 'actions/main'

# torrent daemon
if CONFIG['transmission']
  require_relative 'transmission'
  require_relative 'torrentd'
  TORRENTD = TorrentDaemon.new Transmission::Client.new(CONFIG['transmission'])
  if tv_root = CONFIG['xbmc_tv']
    TORRENTD.on_file_complete do |file|
      if file.name =~ /\.(avi|mkv|mp4|wmv)$/i
        # Links each completed file to tv_root/ShowName/FeedTorrentId_FileBasename
        # There is potential for a collision, but oh well.
        file.torrent.feed_torrents.each do |feed_torrent|
          link_dir = File.join tv_root, feed_torrent.feed.id
          FileUtils.mkdir_p link_dir
          link_path = File.join(link_dir, "#{feed_torrent.id}_#{File.basename file.name}")
          # try to create a hard link so that the original can be deleted, failover to soft
          begin
            FileUtils.ln file.full_path, link_path
          rescue
            puts "FAILED to create a hard link, creating a soft link instead (#{link_path})"
            FileUtils.ln_s file.full_path, link_path
          end
        end
      end
    end
  end
  Thread.new{TORRENTD.start 30, 10*60}
  require_relative 'actions/feeds'
  require_relative 'actions/torrents'
end

# webcam
if CONFIG['allowwebcam']
  require_relative 'webcam'
  WEBCAM = WebcamController.new
  at_exit { WEBCAM.stop }
  require_relative 'actions/webcam'
end

require_relative 'helpers'
