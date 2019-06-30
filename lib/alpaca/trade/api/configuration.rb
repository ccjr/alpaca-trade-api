module Alpaca
  module Trade
    module Api

      class Configuration
        attr_accessor :endpoint, :key_id, :key_secret

        def initialize
          @endpoint = 'https://paper-api.alpaca.markets'
          @key_id = ENV['ALPACA_API_KEY_ID']
          @key_secret = ENV['ALPACA_API_SECRET_KEY']
        end
      end

    end
  end
end
