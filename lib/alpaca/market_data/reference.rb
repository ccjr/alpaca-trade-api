# frozen_string_literal: true

module Alpaca
  module MarketData
    # News articles (/v1beta1/news), newest first by default.
    class News < Base
      # Filters: symbols, start, end, sort, include_content, exclude_contentless. `limit` is the page size.
      operation market_data: "News"
      def list(**params)
        paginate("/v1beta1/news", model: NewsArticle, query: params, items_key: "news")
      end
    end

    # Historical corporate actions (/v1/corporate-actions).
    class CorporateActions < Base
      # Lazily lists CorporateAction records. Filters: symbols, cusips, types
      # (e.g. %w[cash_dividend forward_split]), start, end (process dates), ids, ...
      operation market_data: "CorporateActions"
      def list(**params)
        Collection.new do |cursor|
          response = connection.request(:get, "/v1/corporate-actions", query: cursor ? params.merge(page_token: cursor) : params)
          data = response.data || {}
          token = data["next_page_token"]
          Collection::Page.new(items: actions(data["corporate_actions"], response),
            next_cursor: (token.nil? || token == "") ? nil : token, response: response)
        end
      end

      private

      # {"cash_dividends" => [...], "forward_splits" => [...]} -> records typed :cash_dividend, :forward_split.
      def actions(groups, response)
        (groups || {}).flat_map do |group, items|
          Array(items).map { |item| CorporateAction.new(item, response: response, type: group.delete_suffix("s")) }
        end
      end
    end

    # Corporate action changes as Server-Sent Events.
    class CorporateActionEvents < Base
      # Lazy EventStream of CorporateActionEvent (insert/update/delete of any CA type).
      # Filters: type, region, since, until, since_id, until_id, last_event_id.
      operation market_data: "SubscribeToCorporateActionsEventsSSE"
      def stream(**params)
        EventStream.new(connection, "/v1beta1/events/corporate-actions", query: params, model: CorporateActionEvent)
      end
    end

    class Screener < Base
      # by: :volume (default) or :trades; top: how many (default 10).
      operation market_data: "MostActives"
      def most_actives(**params)
        http_get("/v1beta1/screener/stocks/most-actives", query: params, model: MostActives)
      end

      # Top gainers and losers; market_type: :stocks or :crypto.
      operation market_data: "Movers"
      def movers(market_type = :stocks, **params)
        http_get(path("/v1beta1/screener", market_type, "movers"), query: params, model: Movers)
      end
    end

    # Fixed income (US Treasuries) by ISIN: one object for a String, ISIN => object for an Array.
    class FixedIncome < Base
      operation market_data: "FixedIncomeLatestPrices"
      def latest_prices(isins)
        latest("/v1beta1/fixed_income/latest/prices", isins, "prices", FixedIncomePrice, param: :isins, id: :isin)
      end

      # trade_size: the par amount to quote for.
      operation market_data: "FixedIncomeLatestQuotes"
      def latest_quotes(isins, **params)
        latest("/v1beta1/fixed_income/latest/quotes", isins, "quotes", FixedIncomeQuote, params, param: :isins, id: :isin)
      end
    end

    class Logos < Base
      # The logo image (binary String). placeholder: true returns a generated image for unknown symbols.
      operation market_data: "Logos"
      def fetch(symbol, **params)
        download(path("/v1beta1/logos", symbol), query: params)
      end
    end
  end
end
