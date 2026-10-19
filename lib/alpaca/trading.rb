# frozen_string_literal: true

require_relative "models/account"
require_relative "models/order"
require_relative "models/events"
require_relative "models/position"
require_relative "models/asset"
require_relative "models/market"
require_relative "models/crypto_funding"
require_relative "models/locate"
require_relative "models/tokenization"

require_relative "trading/orders"
require_relative "trading/positions"
require_relative "trading/watchlists"
require_relative "trading/account_details"
require_relative "trading/activities"
require_relative "trading/assets"
require_relative "trading/crypto_funding"
require_relative "trading/tokenization"
require_relative "trading/locates"
require_relative "trading/events"
require_relative "trading/account_scope"
require_relative "trading/client"

module Alpaca
  # Legacy v2 endpoints superseded by v3 equivalents (Client#clock, #calendar).
  OperationRegistry.skip(:trading, "LegacyClock", "superseded by /v3/clock")
  OperationRegistry.skip(:trading, "LegacyCalendar", "superseded by /v3/calendar/{market}")

  class << self
    # Memoized Trading client built from Alpaca.configuration.
    def trading = memoized_client(:trading) { Trading::Client.new }
  end
end
