# frozen_string_literal: true

module Alpaca
  module Trading
    # Short-sale locates for hard-to-borrow symbols (live accounts only).
    class Locates < Resource
      # Lazily lists locates. Filters: status, symbol, start, end, limit.
      operation trading: "listLocates"
      def list(**params)
        paginate("/v1/locates", model: Locate, query: params, items_key: "locates")
      end

      operation trading: "getLocate"
      def find(locate_id)
        http_get(path("/v1/locates", locate_id), model: Locate)
      end

      # Requests a locate. Reusing an idempotency_key returns the original locate.
      operation trading: "createLocates"
      def create(symbol:, qty:, limit_price: nil, all_or_none: nil, idempotency_key: nil)
        body = {symbol: symbol, qty: qty, limit_price: limit_price, all_or_none: all_or_none}
        http_post("/v1/locates", body: body, idempotency_key: idempotency_key, model: Locate)
      end

      # Current borrow availability and price per symbol.
      operation trading: "listLocateQuotes"
      def quotes(symbols)
        http_get("/v1/locates/quotes", query: {symbols: Array(symbols)}, model: LocateQuotes)
      end
    end
  end
end
