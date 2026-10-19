# frozen_string_literal: true

require_relative "models/broker_account"
require_relative "models/broker_funding"
require_relative "models/broker_programs"

require_relative "broker/accounts"
require_relative "broker/funding"
require_relative "broker/programs"
require_relative "broker/extensions"
require_relative "broker/events"
require_relative "broker/client"

module Alpaca
  # Legacy US-only clock and calendar, superseded by /v2/clock and /v2/calendar/{market}.
  OperationRegistry.skip(:broker, "LegacyClock", "superseded by /v2/clock")
  OperationRegistry.skip(:broker, "LegacyCalendar", "superseded by /v2/calendar/{market}")

  class << self
    # Memoized Broker client built from Alpaca.configuration.
    def broker = memoized_client(:broker) { Broker::Client.new }
  end
end
