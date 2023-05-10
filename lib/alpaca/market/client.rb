# frozen_string_literal: true
module Alpaca
  module Market
    class Client < Alpaca::Trade::Api::Client
      HOST = 'https://data.alpaca.markets/'

      def initialize(key_id: Alpaca::Trade::Api.configuration.key_id, key_secret: Alpaca::Trade::Api.configuration.key_secret)
        @key_id = key_id
        @key_secret = key_secret
      end
    end
  end
end