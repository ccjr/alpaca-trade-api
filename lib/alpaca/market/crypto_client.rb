# frozen_string_literal: true
module Alpaca
  module Market
    class CryptoClient < Client
      def bars(symbol, timeframe, limit: 100)
        response = get_request(HOST, "/v1beta3/crypto/us/bars", timeframe: timeframe, limit: limit)
        json = JSON.parse(response.body)
        json['bars'].map { |item| Alpaca::Market::Crypto::Bar.new(item) }
      end
    end
  end
end