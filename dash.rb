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
  require_relative 'actions/feeds'
  require_relative 'actions/torrents'
  Thread.new{TORRENTD.start}
end

# webcam
if CONFIG['allowwebcam']
  require_relative 'webcam'
  WEBCAM = WebcamController.new
  at_exit { WEBCAM.stop }
  require_relative 'actions/webcam'
end

require_relative 'helpers'
