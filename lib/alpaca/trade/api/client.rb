# frozen_string_literal: true

require 'date'
require 'faraday'

module Alpaca
  module Trade
    module Api
      class Client
        attr_reader :data_endpoint, :endpoint, :key_id, :key_secret

        TIMEFRAMES = ['minute', '1Min', '5Min', '15Min', 'day', '1D']

        def initialize(endpoint: Alpaca::Trade::Api.configuration.endpoint,
                       key_id: Alpaca::Trade::Api.configuration.key_id,
                       key_secret: Alpaca::Trade::Api.configuration.key_secret)
          @data_endpoint = Alpaca::Trade::Api.configuration.data_endpoint
          @endpoint = endpoint
          @key_id = key_id
          @key_secret = key_secret
        end

        def account
          response = get_request(endpoint, 'v2/account')
          Account.new(JSON.parse(response.body))
        end

        def account_activities(activity_type:, date:nil, after:nil, until_time:nil, direction:nil, page_size:nil, page_token:nil)
          if date.present? && (until_time.present? || after.present?)
            raise InvalidParameters, 'date cannot be used with either until_time or after'
          end
          params = { date:date, until_time:until_time, after:after, direction:direction, page_size:page_size, page_token:page_token }
          response = get_request(endpoint, "/v2/account/activities/#{activity_type}", params)
          raise InvalidActivityType, JSON.parse(response.body)['message'] if response.status == 422
          json = JSON.parse(response.body)
          activity_class = (TradeActivity::ATTRIBUTES - json.first.to_h.keys).none? ? TradeActivity : NonTradeActivity
          json.map { |item| activity_class.new(item) }
        end

        def asset(symbol:)
          response = get_request(endpoint, "v2/assets/#{symbol}")
          Asset.new(JSON.parse(response.body))
        end

        def assets(status: nil, asset_class: nil)
          response = get_request(endpoint, "v2/assets", { status: status, asset_class: asset_class }.compact)
          json = JSON.parse(response.body)
          json.map { |item| Asset.new(item) }
        end

        # {
        #   "bars": {
        #     "AAPL": [
        #       {
        #         "t": "2022-01-03T09:00:00Z",
        #         "o": 178.26,
        #         "h": 178.26,
        #         "l": 178.21,
        #         "c": 178.21,
        #         "v": 1118,
        #         "n": 65,
        #         "vw": 178.235733
        #       }
        #     ]
        #   },
        #   "next_page_token": "QUFQTHxNfDIwMjItMDEtMDNUMDk6MDA6MDAuMDAwMDAwMDAwWg=="
        # }
        def bars(timeframe: '1D', symbols:, limit: 100, start_date: nil, end_date: nil, feed: 'sip', asof: nil)
          validate_timeframe(timeframe)
          validate_symbols(symbols)

          symbols = Array(symbols)
          params = {
            symbols: symbols.join(','),
            limit: limit,
            timeframe: timeframe,
            feed: feed
          }
          params[:start] = start_date.rfc3339 if start_date
          params[:end]  = end_date.rfc3339 if end_date

          params[:asof] = asof.strftime("%Y-%m-%d") if asof.is_a?(Date) || asof.is_a?(Time)
          params[:asof] ||= asof if asof.is_a?(String)

          response = get_request(data_endpoint, "v2/stocks/bars", params)
          raise InvalidRequest, JSON.parse(response.body)['message'] if response.status == 404

          json = JSON.parse(response.body)
          hash = { "next_page_token" => json["next_page_token"], "bars" => {} }
          symbols.each do |symbol|
            hash["bars"][symbol] = json["bars"][symbol]&.map { |bar| Bar.new(bar) } || []
          end
          hash.merge({ 'next_page_token' => json['next_page_token'] })
        end

        def calendar(start_date: Date.today, end_date: (Date.today + 30))
          # FIX, use start_date.strftime('%F')
          params = { "start" => start_date.iso8601, "end" => end_date.iso8601 }
          response = get_request(endpoint, "v2/calendar", params)
          json = JSON.parse(response.body)
          json.map { |item| Calendar.new(item) }
        end

        def cancel_order(id:)
          response = delete_request(endpoint, "v2/orders/#{id}")
          raise InvalidOrderId, JSON.parse(response.body)['message'] if response.status == 404
          raise OrderNotCancelable if response.status == 422
        end

        def cancel_orders
          response = delete_request(endpoint, 'v2/orders')

          json = JSON.parse(response.body)
          json.map do |item|
            {
              'id' => item['id'],
              'status' => item['status'],
              'body' => Order.new(item['body']),
            }
          end
        end

        def clock
          response = get_request(endpoint, 'v2/clock')
          Clock.new(JSON.parse(response.body))
        end

        def close_position(symbol:)
          response = delete_request(endpoint, "v2/positions/#{symbol}")
          raise NoPositionForSymbol, JSON.parse(response.body)['message'] if response.status == 404

          Position.new(JSON.parse(response.body))
        end

        def close_positions
          response = delete_request(endpoint, 'v2/positions')

          json = JSON.parse(response.body)
          json.map do |item|
            {
              'symbol' => item['symbol'],
              'status' => item['status'],
              'body' => Position.new(item['body']),
            }
          end
        end

        def last_trade(symbol:)
          response = get_request(data_endpoint, "v1/last/stocks/#{symbol}")
          raise InvalidRequest, JSON.parse(response.body)['message'] if response.status == 404

          LastTrade.new(JSON.parse(response.body))
        end

        def new_order(symbol:, side:, type:, time_in_force:, qty: nil, notional: nil,
          limit_price: nil, stop_price: nil, extended_hours: false, client_order_id: nil,
          order_class: nil, take_profit: nil, stop_loss: nil)

          params = {
            symbol: symbol,
            side: side,
            type: type,
            time_in_force: time_in_force,
            qty: qty,
            notional: notional,
            limit_price: limit_price,
            order_class: order_class,
            stop_price: stop_price,
            take_profit: take_profit,
            stop_loss: stop_loss,
            extended_hours: extended_hours,
            client_order_id: client_order_id
          }
          response = post_request(endpoint, 'v2/orders', params.compact)
          raise InsufficientFunds, JSON.parse(response.body)['message'] if response.status == 403
          raise MissingParameters, JSON.parse(response.body)['message'] if response.status == 422

          Order.new(JSON.parse(response.body))
        end

        def order(id:)
          response = get_request(endpoint, "v2/orders/#{id}")
          raise InvalidOrderId, JSON.parse(response.body)['message'] if response.status == 404

          Order.new(JSON.parse(response.body))
        end

        def orders(status: nil, symbols: nil, after: nil, until_time: nil, direction: nil, limit: 50)
          params = { status: status, symbols:symbols, after: after, until: until_time, direction: direction, limit: limit }
          response = get_request(endpoint, "v2/orders", params.compact)
          json = JSON.parse(response.body)
          json.map { |item| Order.new(item) }
        end

        def position(symbol: nil)
          response = get_request(endpoint, ["v2/positions", symbol].compact.join('/'))
          raise NoPositionForSymbol, JSON.parse(response.body)['message'] if response.status == 404

          Position.new(JSON.parse(response.body))
        end

        def positions(symbol: nil)
          response = get_request(endpoint, ["v2/positions", symbol].compact.join('/'))
          json = JSON.parse(response.body)
          json.map { |item| Position.new(item) }
        end

        def replace_order(id:, qty: nil, time_in_force: nil, limit_price: nil,
                          stop_price: nil, client_order_id: nil)

          params = {
            qty: qty,
            time_in_force: time_in_force,
            limit_price: limit_price,
            stop_price: stop_price,
            client_order_id: client_order_id
          }
          response = patch_request(endpoint, "v2/orders/#{id}", params.compact)
          raise InsufficientFunds, JSON.parse(response.body)['message'] if response.status == 403
          raise InvalidOrderId, JSON.parse(response.body)['message'] if response.status == 404
          raise InvalidRequest, JSON.parse(response.body)['message'] if response.status == 422

          Order.new(JSON.parse(response.body))
        end

        private

        def delete_request(endpoint, uri)
          conn = Faraday.new(url: endpoint)
          response = conn.delete(uri) do |req|
            req.headers['APCA-API-KEY-ID'] = key_id
            req.headers['APCA-API-SECRET-KEY'] = key_secret
          end

          possibly_raise_exception(response)
          response
        end

        def get_request(endpoint, uri, params = {})
          conn = Faraday.new(url: endpoint)
          response = conn.get(uri) do |req|
            params.each { |k, v| req.params[k.to_s] = v }
            req.headers['APCA-API-KEY-ID'] = key_id
            req.headers['APCA-API-SECRET-KEY'] = key_secret
          end

          possibly_raise_exception(response)
          response
        end

        def patch_request(endpoint, uri, params = {})
          conn = Faraday.new(url: endpoint)
          response = conn.patch(uri) do |req|
            req.body = params.to_json
            req.headers['APCA-API-KEY-ID'] = key_id
            req.headers['APCA-API-SECRET-KEY'] = key_secret
          end

          possibly_raise_exception(response)
          response
        end

        def post_request(endpoint, uri, params = {})
          conn = Faraday.new(url: endpoint)
          response = conn.post(uri) do |req|
            req.body = params.to_json
            req.headers['APCA-API-KEY-ID'] = key_id
            req.headers['APCA-API-SECRET-KEY'] = key_secret
          end

          possibly_raise_exception(response)
          response
        end

        def possibly_raise_exception(response)
          if response.status == 401
            raise UnauthorizedError, JSON.parse(response.body)['message']
          end
          if response.status == 429
            raise RateLimitedError, JSON.parse(response.body)['message']
          end
          if response.status == 500
            raise InternalServerError, JSON.parse(response.body)['message']
          end
        end

        def validate_timeframe(timeframe)
          return if TIMEFRAMES.include?(timeframe)
          raise ArgumentError, "Invalid timeframe: #{timeframe}. Valid arguments are: #{TIMEFRAMES}"
        end

        def validate_symbols(symbols)
          return if symbols.is_a?(String)
          return if symbols.is_a?(Array) && symbols.all?{ |symbol| symbol.is_a?(String) }
          raise ArgumentError, "Invalid symbols: #{symbols.inspect}. Symbols must be a String or an array of strings."
        end
      end
    end
  end
end
