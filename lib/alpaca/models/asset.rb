# frozen_string_literal: true

module Alpaca
  class Asset < Model
    attribute :id, :string
    attribute :symbol, :string
    attribute :name, :string
    # "class" is a Ruby method name, so the asset class is exposed as #asset_class.
    attribute :class, :symbol
    attribute :exchange, :string
    attribute :status, :symbol
    attribute :cusip, :string
    attribute :tradable, :boolean
    attribute :marginable, :boolean
    attribute :shortable, :boolean
    attribute :easy_to_borrow, :boolean
    attribute :fractionable, :boolean
    attribute :borrow_status, :symbol
    attribute :attributes, [:string]
    attribute :maintenance_margin_requirement, :decimal
    attribute :margin_requirement_long, :decimal
    attribute :margin_requirement_short, :decimal
    attribute :min_order_size, :decimal
    attribute :min_trade_increment, :decimal
    attribute :price_increment, :decimal

    def asset_class = self["class"]
  end

  class OptionDeliverable < Model
    attribute :type, :symbol
    attribute :symbol, :string
    attribute :asset_id, :string
    attribute :amount, :decimal
    attribute :allocation_percentage, :decimal
    attribute :settlement_type, :string
    attribute :settlement_method, :string
    attribute :delayed_settlement, :boolean
  end

  class OptionContract < Model
    attribute :id, :string
    attribute :symbol, :string
    attribute :name, :string
    attribute :status, :symbol
    attribute :tradable, :boolean
    attribute :expiration_date, :date
    attribute :root_symbol, :string
    attribute :underlying_symbol, :string
    attribute :underlying_asset_id, :string
    attribute :type, :symbol
    attribute :style, :symbol
    attribute :strike_price, :decimal
    attribute :multiplier, :decimal
    attribute :size, :decimal
    attribute :open_interest, :decimal
    attribute :open_interest_date, :date
    attribute :close_price, :decimal
    attribute :close_price_date, :date
    attribute :ppind, :boolean
    attribute :deliverables, [OptionDeliverable]
  end

  class CorporateAnnouncement < Model
    attribute :id, :string
    attribute :corporate_action_id, :string
    attribute :ca_type, :symbol
    attribute :ca_sub_type, :symbol
    attribute :initiating_symbol, :string
    attribute :initiating_original_cusip, :string
    attribute :target_symbol, :string
    attribute :target_original_cusip, :string
    attribute :declaration_date, :date
    attribute :ex_date, :date
    attribute :record_date, :date
    attribute :payable_date, :date
    attribute :effective_date, :date
    attribute :cash, :decimal
    attribute :old_rate, :decimal
    attribute :new_rate, :decimal
  end

  class Watchlist < Model
    attribute :id, :string
    attribute :account_id, :string
    attribute :name, :string
    attribute :created_at, :time
    attribute :updated_at, :time
    attribute :assets, [Asset]

    def symbols = Array(assets).map(&:symbol)
  end
end
