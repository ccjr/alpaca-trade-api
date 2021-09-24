# frozen_string_literal: true

require 'date'
require 'faraday'

module Alpaca
  module Trade
    module Api
      class Client
        attr_reader :data_endpoint, :endpoint, :key_id, :key_secret

        TIMEFRAMES = ['1Min', '15Min', '1Hour', '1Day']

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

        def account_activities(activity_type:)
          response = get_request(endpoint, "/v2/account/activities/#{activity_type}")
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

        def bars(timeframe:, symbol:, start:, end_: Time.now, limit: 100)
          validate_timeframe(timeframe)
          response = get_request(data_endpoint, "v2/stocks/#{symbol}/bars", limit: limit, timeframe: timeframe, start: start.utc.strftime('%FT%TZ'), end: end_.utc.strftime('%FT%TZ'))
          raise Unprocessable, JSON.parse(response.body)['message'] if response.status == 422
          raise InvalidRequest, JSON.parse(response.body)['message'] if response.status == 400
          raise RateLimitedError, JSON.parse(response.body)['message'] if response.status == 429
          json = JSON.parse(response.body)
          json["bars"].map { |bar| Bar.new(bar) }
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

        def orders(status: nil, after: nil, until_time: nil, direction: nil, limit: 50)
          params = { status: status, after: after, until: until_time, direction: direction, limit: limit }
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
          unless TIMEFRAMES.include?(timeframe)
            raise ArgumentError, "Invalid timeframe: #{timeframe}. Valid arguments are: #{TIMEFRAMES}"
          end
        end
      end
    end
  end
end
