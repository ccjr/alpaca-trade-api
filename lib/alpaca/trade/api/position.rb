# frozen_string_literal: true

module Alpaca
  module Trade
    module Api
      class Position
        attr_reader :asset_id, :symbol, :exchange, :asset_class, :avg_entry_price,
          :qty, :side, :market_value, :cost_basis, :unrealized_pl, :unrealized_plpc,
          :unrealized_intraday_pl, :unrealized_intraday_plpc, :current_price,
          :lastday_price, :change_today

        def initialize(json)
          @asset_id = json['asset_id']
          @symbol = json['symbol']
          @exchange = json['exchange']
          @asset_class = json['asset_class']
          @avg_entry_price = json['avg_entry_price']
          @qty = json['qty']
          @side = json['side']
          @market_value = json['market_value']
          @cost_basis = json['cost_basis']
          @unrealized_pl = json['unrealized_pl']
          @unrealized_plpc = json['unrealized_plpc']
          @unrealized_intraday_pl = json['unrealized_intraday_pl']
          @unrealized_intraday_plpc = json['unrealized_intraday_plpc']
          @current_price = json['current_price']
          @lastday_price = json['lastday_price']
          @change_today = json['change_today']
        end
      end
    end
  end
end
