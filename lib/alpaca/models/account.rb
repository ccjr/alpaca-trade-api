# frozen_string_literal: true

module Alpaca
  # Trading account (Trading API /v2/account, Broker /v1/trading/accounts/{id}/account).
  class Account < Model
    attribute :id, :string
    attribute :account_number, :string
    attribute :status, :symbol
    attribute :crypto_status, :symbol
    attribute :currency, :string
    attribute :created_at, :time
    attribute :balance_asof, :date
    attribute :account_blocked, :boolean
    attribute :trading_blocked, :boolean
    attribute :transfers_blocked, :boolean
    attribute :trade_suspended_by_user, :boolean
    attribute :shorting_enabled, :boolean
    attribute :pattern_day_trader, :boolean
    attribute :daytrade_count, :integer
    attribute :options_approved_level, :integer
    attribute :options_trading_level, :integer
    %i[
      accrued_fees buying_power cash equity initial_margin intraday_adjustments last_equity
      last_maintenance_margin long_market_value maintenance_margin multiplier
      non_marginable_buying_power options_buying_power pending_reg_taf_fees pending_transfer_in
      pending_transfer_out portfolio_value regt_buying_power short_market_value sma
      daytrading_buying_power last_buying_power last_cash last_daytrading_buying_power
      last_initial_margin last_long_market_value last_regt_buying_power last_short_market_value
      cash_withdrawable cash_transferable effective_buying_power
    ].each { |name| attribute name, :decimal }
  end

  class AccountConfigurations < Model
    attribute :dtbp_check, :symbol
    attribute :trade_confirm_email, :symbol
    attribute :pdt_check, :symbol
    attribute :suspend_trade, :boolean
    attribute :no_shorting, :boolean
    attribute :fractional_trading, :boolean
    attribute :disable_overnight_trading, :boolean
    attribute :ptp_no_exception_entry, :boolean
    attribute :max_margin_multiplier, :decimal
    attribute :max_options_trading_level, :integer
  end

  # Equity and P/L time series. `points` zips the parallel arrays into rows.
  class PortfolioHistory < Model
    Point = Data.define(:time, :equity, :profit_loss, :profit_loss_pct)

    attribute :timestamp, [:integer]
    attribute :equity, [:decimal]
    attribute :profit_loss, [:decimal]
    attribute :profit_loss_pct, [:decimal]
    attribute :base_value, :decimal
    attribute :base_value_asof, :date
    attribute :timeframe, :string

    def points
      Array(timestamp).each_with_index.map do |ts, i|
        Point.new(time: Time.at(ts).utc, equity: equity&.[](i), profit_loss: profit_loss&.[](i),
          profit_loss_pct: profit_loss_pct&.[](i))
      end
    end
  end

  # Account activity: trade activities (FILL) and non-trade activities (DIV, FEE, JNLC, ...)
  # share this class; `trade?` tells them apart.
  class Activity < Model
    attribute :id, :string
    attribute :activity_type, :string
    attribute :activity_sub_type, :string
    attribute :transaction_time, :time
    attribute :type, :symbol
    attribute :side, :symbol
    attribute :symbol, :string
    attribute :order_id, :string
    attribute :order_status, :symbol
    attribute :price, :decimal
    attribute :qty, :decimal
    attribute :cum_qty, :decimal
    attribute :leaves_qty, :decimal
    attribute :date, :raw
    attribute :created_at, :time
    attribute :net_amount, :decimal
    attribute :per_share_amount, :decimal
    attribute :status, :symbol
    attribute :currency, :string
    attribute :description, :string

    def trade? = activity_type == "FILL"
  end
end
