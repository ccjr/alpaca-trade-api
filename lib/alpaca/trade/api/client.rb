require 'faraday'

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

        def account()
          response = get_request("v2/account")
          Account.new(JSON.parse(response.body))
        end

        def asset(symbol:)
          response = get_request("v2/assets/#{symbol}")
          Asset.new(JSON.parse(response.body))
        end

        private

        def get_request(uri)
          conn = Faraday.new(:url => endpoint)
          response = conn.get(uri) do |req|
            req.headers['APCA-API-KEY-ID'] = key_id
            req.headers['APCA-API-SECRET-KEY'] = key_secret
          end

          raise UnauthorizedError, JSON.parse(response.body)['message'] if response.status == 401
          raise RateLimitedError, JSON.parse(response.body)['message'] if response.status == 429

          response
        end
      end

    end
  end
end
