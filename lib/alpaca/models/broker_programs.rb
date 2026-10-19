# frozen_string_literal: true

module Alpaca
  # Rebalancing model portfolio.
  class RebalancingPortfolio < Model
    attribute :id, :string
    attribute :name, :string
    attribute :description, :string
    attribute :status, :symbol
    attribute :cooldown_days, :integer
    attribute :weights, :raw
    attribute :rebalance_conditions, :raw
    attribute :created_at, :time
    attribute :updated_at, :time
  end

  class RebalancingRun < Model
    attribute :id, :string
    attribute :account_id, :string
    attribute :portfolio_id, :string
    attribute :type, :symbol
    attribute :status, :symbol
    attribute :initiated_from, :symbol
    attribute :reason, :string
    attribute :amount, :decimal
    attribute :weights, :raw
    attribute :orders, [Order]
    attribute :failed_orders, [Order]
    attribute :skipped_orders, :raw
    attribute :completed_at, :time
    attribute :canceled_at, :time
    attribute :created_at, :time
    attribute :updated_at, :time
  end

  class RebalancingSubscription < Model
    attribute :id, :string
    attribute :account_id, :string
    attribute :portfolio_id, :string
    attribute :last_rebalanced_at, :time
    attribute :created_at, :time
  end

  class IPOOffering < Model
    attribute :ipo_reference, :string
    attribute :ticker_symbol, :string
    attribute :name, :string
    attribute :description, :string
    attribute :cusip_id, :string
    attribute :availability, :symbol
    attribute :offering_type, :string
    attribute :min_price, :decimal
    attribute :max_price, :decimal
    attribute :min_ticket_size, :decimal
    attribute :max_ticket_size, :decimal
    attribute :unit_step_size, :decimal
    attribute :anticipated_shares, :integer
    attribute :no_new_orders, :boolean
    attribute :trade_date, :date
    attribute :settlement_date, :date
    attribute :underwriters, [:string]
    attribute :prospectus_url, :string
    attribute :logo_small, :string
  end

  # Fully Paid Securities Lending.
  class FPSLLoan < Model
    attribute :account_id, :string
    attribute :account_number, :string
    attribute :correspondent, :string
    attribute :symbol, :string
    attribute :quantity, :integer
    attribute :market_value, :decimal
    attribute :collateral, :decimal
    attribute :date, :date
    attribute :interest, :raw
    attribute :updated_at, :time
  end

  class FPSLTier < Model
    attribute :id, :string
    attribute :tier_name, :string
    attribute :market, :string
    attribute :customer_split, :decimal
    attribute :partner_split, :decimal
    attribute :created_at, :time
    attribute :updated_at, :time
  end

  class APRTier < Model
    attribute :id, :string
    attribute :name, :string
    attribute :currency, :string
    attribute :is_default, :boolean
    attribute :account_rate_bps, :integer
    attribute :correspondent_rate_bps, :integer
    attribute :details, :raw
    attribute :created_at, :time
    attribute :updated_at, :time
  end

  class DailyCashInterest < Model
    attribute :account_id, :string
    attribute :date, :date
    attribute :currency, :string
    attribute :apr_tier_id, :string
    attribute :apr_tier_name, :string
    attribute :account_rate_bps, :integer
    attribute :correspondent_rate_bps, :integer
    attribute :cash_balance, :decimal
    attribute :account_accrued_interest, :decimal
    attribute :correspondent_fee, :decimal
  end

  class AggregatePosition < Model
    attribute :symbol, :string
    attribute :cusip, :string
    attribute :asset_type, :symbol
    attribute :num_accounts, :integer
    attribute :closing_price, :decimal
    attribute :long_qty, :decimal
    attribute :short_qty, :decimal
    attribute :long_market_value, :decimal
    attribute :short_market_value, :decimal
  end

  # Fixed income reference data (/v1/assets/fixed_income/*).
  class Bond < Model
    attribute :cusip, :string
    attribute :isin, :string
    attribute :ticker, :string
    attribute :issuer, :string
    attribute :description, :string
    attribute :description_short, :string
    attribute :subtype, :symbol
    attribute :bond_status, :symbol
    attribute :tradable, :boolean
    attribute :fractionable, :boolean
    attribute :marginable, :boolean
    attribute :coupon, :decimal
    attribute :coupon_type, :symbol
    attribute :coupon_frequency, :symbol
    attribute :close_price, :decimal
    attribute :close_price_date, :date
    attribute :close_yield_to_maturity, :decimal
    attribute :close_yield_to_worst, :decimal
    attribute :par_value, :decimal
    attribute :issue_price, :decimal
    attribute :accrued_interest, :decimal
    attribute :issue_date, :date
    attribute :maturity_date, :date
    attribute :dated_date, :date
    attribute :first_coupon_date, :date
    attribute :next_coupon_date, :date
    attribute :last_coupon_date, :date
    attribute :next_call_date, :date
    attribute :next_call_price, :decimal
  end
end
