# frozen_string_literal: true

module Alpaca
  module Trading
    # Asset master list. Scope "/v2" (Trading) or "/v1" (Broker).
    class Assets < Resource
      # Filters: status (:active, :inactive), asset_class (:us_equity, :us_option, :crypto, ...),
      # exchange, attributes (e.g. %w[has_options fractional_eh_enabled]).
      operation trading: "get-v2-assets", broker: "getAssets"
      def list(**params)
        http_get(scoped("assets"), query: params, model: Asset) || []
      end

      operation trading: "get-v2-assets-symbol_or_asset_id", broker: "getAssetBySymbolOrId"
      def find(symbol_or_asset_id)
        http_get(scoped("assets", symbol_or_asset_id), model: Asset)
      end
    end

    # Option contracts. Scope "/v2" (Trading) or "/v1" (Broker).
    class OptionContracts < Resource
      # Lazily lists contracts, following pages. By default the API returns
      # active contracts expiring before the coming weekend.
      #
      #   option_contracts.list(underlying_symbols: %w[AAPL], type: :call,
      #                         expiration_date_lte: Date.today + 30, strike_price_gte: 150)
      operation trading: "get-options-contracts", broker: "get-options-contracts"
      def list(**params)
        paginate(scoped("options/contracts"), model: OptionContract, query: {limit: 10_000}.merge(params),
          items_key: "option_contracts")
      end

      operation trading: "get-option-contract-symbol_or_id", broker: "get-option-contract-symbol_or_id"
      def find(symbol_or_id)
        http_get(scoped("options/contracts", symbol_or_id), model: OptionContract)
      end
    end

    # Corporate action announcements. Scope "/v2" (Trading) or "/v1" (Broker).
    # Market data's /v1/corporate-actions has richer, historical data.
    class CorporateActions < Resource
      # ca_types: %w[dividend merger spinoff split]; since/until: dates at most 90 days apart.
      operation trading: "get-v2-corporate_actions-announcements", broker: "getCorporateAnnouncements"
      def announcements(ca_types:, since:, **params)
        query = {ca_types: ca_types, since: since, **params}
        http_get(scoped("corporate_actions/announcements"), query: query, model: CorporateAnnouncement) || []
      end

      operation trading: "get-v2-corporate_actions-announcements-id", broker: "get-GET-v1-corporate_actions-announcements-id"
      def announcement(id)
        http_get(scoped("corporate_actions/announcements", id), model: CorporateAnnouncement)
      end
    end

    # Market clocks and calendars. Scope "/v3" (Trading) or "/v2" (Broker).
    class Calendars < Resource
      # Clocks for several markets; markets: e.g. %w[NYSE NASDAQ], time: a past/future instant.
      operation trading: "Clock", broker: "Clock"
      def clocks(**params)
        data = http_get(scoped("clock"), query: params)
        Clock.build(data && data["clocks"]) || []
      end

      # Trading days for one market between start and end (dates).
      operation trading: "Calendar", broker: "Calendar"
      def calendar(market, **params)
        http_get(scoped("calendar", market), query: params, model: Alpaca::MarketCalendar)
      end
    end
  end
end
