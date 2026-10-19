# frozen_string_literal: true

module Alpaca
  module Trading
    class Watchlists < Resource
      # Watchlists without their assets; use #find for the full list of assets.
      operation trading: "getWatchlists", broker: "getAllWatchlistsForAccount"
      def list
        http_get(scoped("watchlists"), model: Watchlist) || []
      end

      operation trading: "getWatchlistById", broker: "getWatchlistForAccountById"
      def find(watchlist_id)
        http_get(scoped("watchlists", watchlist_id), model: Watchlist)
      end

      operation trading: "getWatchlistByName"
      def find_by_name(name)
        http_get(by_name, query: {name: name}, model: Watchlist)
      end

      operation trading: "postWatchlist", broker: "createWatchlistForAccount"
      def create(name:, symbols: [])
        http_post(scoped("watchlists"), body: {name: name, symbols: symbols}, model: Watchlist)
      end

      # Replaces the name and/or the full symbol list.
      operation trading: "updateWatchlistById", broker: "replaceWatchlistForAccountById"
      def update(watchlist_id, name: nil, symbols: nil)
        http_put(scoped("watchlists", watchlist_id), body: {name: name, symbols: symbols}, model: Watchlist)
      end

      operation trading: "updateWatchlistByName"
      def update_by_name(name, new_name: nil, symbols: nil)
        http_put(by_name, query: {name: name}, body: {name: new_name, symbols: symbols}, model: Watchlist)
      end

      operation trading: "addAssetToWatchlist", broker: "post-v1-trading-accounts-account_id-watchlists-watchlist_id"
      def add(watchlist_id, symbol)
        http_post(scoped("watchlists", watchlist_id), body: {symbol: symbol}, model: Watchlist)
      end

      operation trading: "addAssetToWatchlistByName"
      def add_by_name(name, symbol)
        http_post(by_name, query: {name: name}, body: {symbol: symbol}, model: Watchlist)
      end

      operation trading: "removeAssetFromWatchlist",
        broker: "delete-DELETE-v1-trading-accounts-account_id-watchlists-watchlist_id-symbol"
      def remove(watchlist_id, symbol)
        http_delete(scoped("watchlists", watchlist_id, symbol), model: Watchlist)
      end

      operation trading: "deleteWatchlistById", broker: "deleteWatchlistFromAccountById"
      def delete(watchlist_id)
        http_delete(scoped("watchlists", watchlist_id))
        true
      end

      operation trading: "deleteWatchlistByName"
      def delete_by_name(name)
        http_delete(by_name, query: {name: name})
        true
      end

      private

      def by_name = "#{scope}/watchlists:by_name"
    end
  end
end
