# frozen_string_literal: true

module Alpaca
  module Trade
    module Api
      class NonTradeActivity
        attr_reader :id, :activity_type, :date, :net_ammount, :symbol, :qty, :per_share_amount

        def initialize(json)
          @id = json['id']
          @activity_type = json['activity_type']
          @date = json['date']
          @net_ammount = json['net_ammount']
          @symbol = json['symbol']
          @qty = json['qty']
          @per_share_amount = json['per_share_amount']
        end
      end
    end
  end
end
