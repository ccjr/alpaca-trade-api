# frozen_string_literal: true

require 'date'
require 'faraday'

module Alpaca
  module Trade
    module Api
      class Client
        attr_reader :data_endpoint, :endpoint, :key_id, :key_secret

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

        def asset(symbol:)
          response = get_request(endpoint, "v2/assets/#{symbol}")
          Asset.new(JSON.parse(response.body))
        end

        def assets(status: nil, asset_class: nil)
          response = get_request(endpoint, "v2/assets", { status: status, asset_class: asset_class }.compact)
          json = JSON.parse(response.body)
          json.map { |item| Asset.new(item) }
        end

        def bars(timeframe, symbols, limit: 100)
          response = get_request(data_endpoint, "v1/bars/#{timeframe}", symbols: symbols.join(','), limit: limit)
          json = JSON.parse(response.body)
          json.keys.each_with_object({}) do |symbol, hash|
            hash[symbol] = json[symbol].map { |bar| Bar.new(bar) }
          end
        end

        def calendar(start_date: Date.today, end_date: (Date.today + 30))
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

        def clock
          response = get_request(endpoint, 'v2/clock')
          Clock.new(JSON.parse(response.body))
        end

        def new_order(symbol:, qty:, side:, type:, time_in_force:, limit_price: nil,
          stop_price: nil, extended_hours: false, client_order_id: nil)

          params = {
            symbol: symbol,
            qty: qty,
            side: side,
            type: type,
            time_in_force: time_in_force,
            limit_price: limit_price,
            stop_price: stop_price,
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
      end
    end
  end
end
