# frozen_string_literal: true

require_relative "models/market_data"

require_relative "market_data/series"
require_relative "market_data/base"
require_relative "market_data/stocks"
require_relative "market_data/crypto"
require_relative "market_data/options"
require_relative "market_data/reference"
require_relative "market_data/client"

module Alpaca
  class << self
    # Memoized Market Data client built from Alpaca.configuration.
    def market_data = memoized_client(:market_data) { MarketData::Client.new }
  end
end
