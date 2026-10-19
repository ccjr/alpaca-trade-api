# frozen_string_literal: true

module Alpaca
  # Short-sale locate (live trading only).
  class Locate < Model
    attribute :id, :string
    attribute :symbol, :string
    attribute :status, :symbol
    attribute :all_or_none, :boolean
    attribute :requested_qty, :integer
    attribute :located_qty, :integer
    attribute :limit_price, :decimal
    attribute :located_price, :decimal
    attribute :total_fee, :decimal
    attribute :rejection_reason, :string
    attribute :created_at, :time
    attribute :expires_at, :time
  end

  class LocateQuote < Model
    attribute :symbol, :string
    attribute :available_qty, :integer
    attribute :price, :decimal
    attribute :quoted_at, :time
  end

  # Quotes plus per-symbol errors (symbol_not_found, easy_to_borrow, ...).
  class LocateQuotes < Model
    attribute :quotes, [LocateQuote]
    attribute :errors, :raw
  end
end
