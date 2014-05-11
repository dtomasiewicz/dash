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
set :erb, escape_html: true

# database setup
DB = Sequel.sqlite CONFIG['database']
require_relative 'models'

# actions
get '/' do
  erb :home
end

require_relative 'webcam'
require_relative 'feeds'
require_relative 'helpers'
