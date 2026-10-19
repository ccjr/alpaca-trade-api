# frozen_string_literal: true

module Alpaca
  # Base for streamed events (SSE and WebSocket). `event_id` is a ULID string on
  # v2 endpoints and an integer on legacy ones (which also carry `event_ulid`).
  class Event < Model
    attribute :event_id, :raw
    attribute :event_ulid, :string
    attribute :at, :time
    attribute :account_id, :string
  end

  # Order lifecycle event: SSE /v2/events/trades and the trade_updates WebSocket.
  # `event` is :new, :fill, :partial_fill, :canceled, :expired, :replaced, ...
  class TradeEvent < Event
    attribute :event, :symbol
    attribute :order, Order
    attribute :legs, [Order]
    attribute :timestamp, :time
    attribute :price, :decimal
    attribute :qty, :decimal
    attribute :position_qty, :decimal
    attribute :swap_rate, :decimal
    attribute :execution_id, :string
    attribute :previous_execution_id, :string
    attribute :settle_date, :date

    def fill? = %i[fill partial_fill].include?(event)
  end

  # Account activity (trade and non-trade) event, v2beta1 activities stream.
  class ActivityEvent < Event
    attribute :activity_type, :string
    attribute :activity_subtype, :string
    attribute :status, :string
    attribute :qty, :decimal
    attribute :price, :decimal
    attribute :net_amount, :decimal
    attribute :swap_rate, :decimal
    attribute :swap_fee_bps, :decimal
    attribute :currency, :string
    attribute :executed_at, :time
    attribute :settle_date, :date
  end

  class AccountStatusEvent < Event
    attribute :account_number, :string
    attribute :status_from, :symbol
    attribute :status_to, :symbol
    attribute :crypto_status_from, :symbol
    attribute :crypto_status_to, :symbol
    attribute :account_blocked, :boolean
    attribute :trading_blocked, :boolean
    attribute :reason, :string
  end

  class JournalEvent < Event
    attribute :journal_id, :string
    attribute :entry_type, :symbol
    attribute :status_from, :raw
    attribute :status_to, :symbol
    attribute :description, :string
  end

  class TransferEvent < Event
    attribute :transfer_id, :string
    attribute :status_from, :symbol
    attribute :status_to, :symbol
  end

  class FundingEvent < Event
    attribute :entity_id, :string
    attribute :entity_type, :string
    attribute :status_from, :symbol
    attribute :status_to, :symbol
    attribute :reason, :string
  end

  class NonTradeActivityEvent < Event
    attribute :id, :string
    attribute :entry_type, :string
    attribute :symbol, :string
    attribute :status, :symbol
    attribute :qty, :decimal
    attribute :price, :decimal
    attribute :per_share_amount, :decimal
    attribute :net_amount, :decimal
    attribute :system_date, :date
    attribute :settle_date, :date
  end
end
