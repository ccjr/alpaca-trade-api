# frozen_string_literal: true

module Alpaca
  module MarketData
    # Base for market data records. Alpaca's short wire keys ("t", "bp",
    # "dailyBar") get readable names; the wire keys stay reachable through #[]
    # (bar[:c] == bar.close). `symbol` is set from the response so records from
    # multi-symbol requests can be told apart.
    class Record < Model
      attribute :symbol, :string

      class << self
        # Declares an attribute read from a differently named wire key.
        def field(name, wire_key, type = :raw)
          attribute(name, type)
          own_wire_names[wire_key.to_s] = name.to_s
        end

        def wire_names
          @wire_names ||= ((superclass < Record) ? superclass.wire_names : {}).merge(own_wire_names)
        end

        private

        def own_wire_names = (@own_wire_names ||= {})
      end

      def initialize(attributes = nil, response: nil, **fields)
        names = self.class.wire_names
        attributes = attributes&.transform_keys { |key| names.fetch(key.to_s, key) }
        super
      end

      def [](key) = super(wire_name(key))

      def key?(key) = super(wire_name(key))

      private

      def wire_name(key) = self.class.wire_names.fetch(key.to_s, key)
    end

    class Bar < Record
      field :timestamp, "t", :time
      field :open, "o", :decimal
      field :high, "h", :decimal
      field :low, "l", :decimal
      field :close, "c", :decimal
      field :volume, "v", :integer
      field :trade_count, "n", :integer
      field :vwap, "vw", :decimal
    end

    # Crypto volumes are fractional.
    class CryptoBar < Bar
      field :volume, "v", :decimal
    end

    class Trade < Record
      field :timestamp, "t", :time
      field :price, "p", :decimal
      field :size, "s", :integer
      field :exchange, "x", :string
      field :id, "i", :integer
      field :conditions, "c", :raw
      field :tape, "z", :string
      field :update, "u", :string
    end

    class CryptoTrade < Trade
      field :size, "s", :decimal
      field :taker_side, "tks", :symbol
    end

    # Option trades carry a single condition code.
    class OptionTrade < Trade
      field :condition, "c", :string
    end

    class Quote < Record
      field :timestamp, "t", :time
      field :bid_price, "bp", :decimal
      field :bid_size, "bs", :integer
      field :bid_exchange, "bx", :string
      field :ask_price, "ap", :decimal
      field :ask_size, "as", :integer
      field :ask_exchange, "ax", :string
      field :conditions, "c", :raw
      field :tape, "z", :string
    end

    class CryptoQuote < Quote
      field :bid_size, "bs", :decimal
      field :ask_size, "as", :decimal
    end

    class OptionQuote < Quote
      field :condition, "c", :string
    end

    # One opening or closing auction print.
    class Auction < Record
      field :timestamp, "t", :time
      field :price, "p", :decimal
      field :size, "s", :integer
      field :exchange, "x", :string
      field :condition, "c", :string
    end

    # A trading day's opening and closing auctions for one symbol.
    class DailyAuction < Record
      field :date, "d", :date
      field :opening, "o", [Auction]
      field :closing, "c", [Auction]
    end

    class OrderbookLevel < Record
      field :price, "p", :decimal
      field :size, "s", :decimal
    end

    class Orderbook < Record
      field :timestamp, "t", :time
      field :bids, "b", [OrderbookLevel]
      field :asks, "a", [OrderbookLevel]
      # Streams only: true when the message replaces the whole book; otherwise
      # levels are upserts and a size of 0 removes the level.
      field :reset, "r", :boolean
    end

    class Snapshot < Record
      field :latest_trade, "latestTrade", Trade
      field :latest_quote, "latestQuote", Quote
      field :minute_bar, "minuteBar", Bar
      field :daily_bar, "dailyBar", Bar
      field :prev_daily_bar, "prevDailyBar", Bar
    end

    class CryptoSnapshot < Snapshot
      field :latest_trade, "latestTrade", CryptoTrade
      field :latest_quote, "latestQuote", CryptoQuote
      field :minute_bar, "minuteBar", CryptoBar
      field :daily_bar, "dailyBar", CryptoBar
      field :prev_daily_bar, "prevDailyBar", CryptoBar
    end

    class Greeks < Model
      attribute :delta, :decimal
      attribute :gamma, :decimal
      attribute :rho, :decimal
      attribute :theta, :decimal
      attribute :vega, :decimal
    end

    class OptionSnapshot < Snapshot
      field :latest_trade, "latestTrade", OptionTrade
      field :latest_quote, "latestQuote", OptionQuote
      field :implied_volatility, "impliedVolatility", :decimal
      attribute :greeks, Greeks
    end

    class NewsImage < Model
      attribute :size, :symbol
      attribute :url, :string
    end

    class NewsArticle < Model
      attribute :id, :integer
      attribute :headline, :string
      attribute :author, :string
      attribute :source, :string
      attribute :summary, :string
      attribute :content, :string
      attribute :url, :string
      attribute :symbols, [:string]
      attribute :images, [NewsImage]
      attribute :created_at, :time
      attribute :updated_at, :time
    end

    class StockMovement < Model
      attribute :symbol, :string
      attribute :cusip, :string
      attribute :isin, :string
      attribute :new_rate, :decimal
      attribute :source_rate, :decimal
    end

    # One corporate action from /v1/corporate-actions. `type` is the action
    # type as accepted by the `types:` filter (:cash_dividend, :forward_split, ...);
    # which other fields are present depends on it.
    class CorporateAction < Model
      attribute :type, :symbol
      attribute :id, :string
      %i[
        rate new_rate old_rate cash_rate source_rate alternate_rate acquirer_rate acquiree_rate
        long_term_rate short_term_rate dividend_rate price
      ].each { |name| attribute name, :decimal }
      %i[
        process_date ex_date record_date payable_date effective_date expiration_date due_bill_on_date
        due_bill_off_date due_bill_redemption_date lottery_date results_publication_date
      ].each { |name| attribute name, :date }
      attribute :foreign, :boolean
      attribute :special, :boolean
      attribute :stock_movements, [StockMovement]
    end

    class MostActive < Model
      attribute :symbol, :string
      attribute :volume, :integer
      attribute :trade_count, :integer
    end

    class MostActives < Model
      attribute :most_actives, [MostActive]
      attribute :last_updated, :time
    end

    class Mover < Model
      attribute :symbol, :string
      attribute :price, :decimal
      attribute :change, :decimal
      attribute :percent_change, :decimal
    end

    class Movers < Model
      attribute :market_type, :symbol
      attribute :gainers, [Mover]
      attribute :losers, [Mover]
      attribute :last_updated, :time
    end

    # Fixed income records are keyed by ISIN rather than symbol.
    class FixedIncomePrice < Record
      attribute :isin, :string
      field :timestamp, "t", :time
      field :price, "p", :decimal
      field :yield_to_maturity, "ytm", :decimal
      field :yield_to_worst, "ytw", :decimal
    end

    class FixedIncomeQuote < Record
      attribute :isin, :string
      field :timestamp, "t", :time
      field :bid_price, "bp", :decimal
      field :bid_size, "bs", :integer
      field :bid_min_size, "bms", :integer
      field :bid_yield_to_maturity, "bytm", :decimal
      field :bid_yield_to_worst, "bytw", :decimal
      field :ask_price, "ap", :decimal
      field :ask_size, "as", :integer
      field :ask_min_size, "ams", :integer
      field :ask_yield_to_maturity, "aytm", :decimal
      field :ask_yield_to_worst, "aytw", :decimal
    end

    # One corporate action change from the SSE stream; `ca` holds the action's fields.
    class CorporateActionEvent < ::Alpaca::Event
      attribute :action, :symbol
      attribute :event_type, :string
      attribute :region, :string
      attribute :ca, :raw
    end
  end
end
