module Alpaca
  module Trade
    module Api

      class Asset
        attr_reader :id, :asset_class, :exchange, :symbol, :status, :tradable, :marginable,
          :shortable, :easy_to_borrow

        def initialize(json)
          @id = json['id']
          @asset_class = json['class']
          @exchange = json['exchange']
          @symbol = json['symbol']
          @status = json['status']
          @tradable = json['tradable']
          @marginable = json['marginable']
          @shortable = json['shortable']
          @easy_to_borrow = json['easy_to_borrow']
        end
      end

    end
  end
end
