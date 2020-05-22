module Alpaca
  module Trade
    module Api
      class LastTrade
        attr_reader :status, :symbol, :last

        def initialize(json)
          @status = json['status']
          @symbol = json['symbol']
          @last = json['last']
        end
      end
    end
  end
end
