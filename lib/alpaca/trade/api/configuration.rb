module Alpaca
  module Trade
    module Api

      class Configuration
        attr_accessor :endpoint, :key_id, :key_secret

        def initialize
          @endpoint = 'https://paper-api.alpaca.markets'
        end
      end

    end
  end
end
