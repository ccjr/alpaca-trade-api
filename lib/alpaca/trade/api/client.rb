require 'faraday'
# require 'uri'

module Alpaca
  module Trade
    module Api

      class Client
        attr_reader :endpoint, :key_id, :key_secret

        def initialize(endpoint: Alpaca::Trade::Api.configuration.endpoint,
                       key_id: Alpaca::Trade::Api.configuration.key_id,
                       key_secret: Alpaca::Trade::Api.configuration.key_secret)
          @endpoint = endpoint
          @key_id = key_id
          @key_secret = key_secret
        end

        def asset(symbol:)
          conn = Faraday.new(:url => endpoint)
          response = conn.get("v2/assets/#{symbol}") do |req|
            req.headers['APCA-API-KEY-ID'] = key_id
            req.headers['APCA-API-SECRET-KEY'] = key_secret
          end

          # TODO: handle errors
          Alpaca::Trade::Api::Asset.new(JSON.parse(response.body))
        end
      end

    end
  end
end
