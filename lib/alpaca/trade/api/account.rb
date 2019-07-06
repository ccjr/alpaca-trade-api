# frozen_string_literal: true

module Alpaca
  module Trade
    module Api
      class Account
        attr_reader :id, :status, :currency, :buying_power, :cash, :portfolio_value,
                    :pattern_day_trader, :trade_suspended_by_user, :trading_blocked,
                    :transfers_blocked, :account_blocked, :created_at, :shorting_enabled,
                    :multiplier, :long_market_value, :short_market_value, :equity,
                    :last_equity, :initial_margin, :maintenance_margin, :daytrade_count,
                    :sma

        def initialize(json)
          @id = json['id']
          @status = json['status']
          @currency = json['currency']
          @buying_power = BigDecimal(json['buying_power'])
          @cash = BigDecimal(json['cash'])
          @portfolio_value = BigDecimal(json['portfolio_value'])
          @pattern_day_trader = json['pattern_day_trader']
          @trade_suspended_by_user = json['trade_suspended_by_user']
          @trading_blocked = json['trading_blocked']
          @transfers_blocked = json['transfers_blocked']
          @created_at = json['created_at']
          @shorting_enabled = json['shorting_enabled']
          @multiplier = json['multiplier']
          @long_market_value = BigDecimal(json['long_market_value'])
          @short_market_value = BigDecimal(json['short_market_value'])
          @equity = BigDecimal(json['equity'])
          @last_equity = BigDecimal(json['last_equity'])
          @initial_margin = BigDecimal(json['initial_margin'])
          @maintenance_margin = BigDecimal(json['maintenance_margin'])
          @daytrade_count = json['daytrade_count']
          @sma = json['sma']
        end
      end
    end
  end
end
