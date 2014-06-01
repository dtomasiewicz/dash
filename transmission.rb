require 'net/http'
require 'json'

module Transmission

  class Failure < StandardError; end

  class Client

    attr_reader :error

    class RPCError < StandardError
      attr_reader :response
      def initialize response
        @response = response
        super(response.body)
      end
      def to_s
        "#{@response.class.name} (#{@response.code}): #{super}"
      end
    end

    SESSION_ID_HEADER = 'x-transmission-session-id'

    def initialize config
      @config = {
        'host' => 'localhost',
        'port' => 9091,
        'request_uri' => '/transmission/rpc'
      }.merge config
      @http = Net::HTTP.new @config['host'], @config['port']
    end

    def server
      "#{@config['host']}:#{@config['port']}#{@config['request_uri']}"
    end

    def add_torrent filename
      result = rpc 'torrent-add', 'filename' => filename
      if result['result'] == 'success'
        result['arguments']['torrent-added'] || result['arguments']['torrent-duplicate']
      else
        raise Failure.new result['result']
      end
    end

    def get_torrents fields, ids = []
      result = rpc 'torrent-get', 'fields' => fields, 'ids' => ids
      if result['result'] == 'success'
        result['arguments']['torrents']
      else
        raise Failure.new result['result']
      end
    end

    private

    def http_call body = nil
      request = Net::HTTP::Post.new @config['request_uri']
      request.basic_auth @config['username'], @config['password'] if @config['username']
      request[SESSION_ID_HEADER] = @session_id
      request.body = body
      response = @http.request request
      # retry once if our session has expired
      if Net::HTTPConflict === response
        request[SESSION_ID_HEADER] = @session_id = response[SESSION_ID_HEADER]
        response = @http.request request
      end
      response
    end

    def rpc method, arguments = {}, tag = nil
      http_response = http_call JSON.dump('method' => method, 'arguments' => arguments, 'tag' => tag)
      if !(Net::HTTPOK === http_response)
        @error = RPCError.new http_response
        raise @error
      else
        @error = nil
      end
      JSON.parse http_response.body
    end

  end

end
