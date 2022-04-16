# frozen_string_literal: true

require 'date'
require 'faraday'

module Alpaca
  module Market
    class Client < Alpaca::Trade::Api::Client
      HOST = 'https://data.alpaca.markets/v2'

      def initialize(key_id: Alpaca::Trade::Api.configuration.key_id, key_secret: Alpaca::Trade::Api.configuration.key_secret)
        @key_id = key_id
        @key_secret = key_secret
      end

      def crypto_bars(symbol, timeframe, limit: 100)
        response = get_request(HOST, "/v1beta1/crypto/#{symbol}/bars", timeframe: timeframe, limit: limit)
        json = JSON.parse(response.body)
        json['bars'].map { |item| Alpaca::Market::Crypto::Bar.new(item) }
      end
    end
  end
end