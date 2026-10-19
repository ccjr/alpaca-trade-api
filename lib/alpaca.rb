# frozen_string_literal: true

require "bigdecimal"
require "date"
require "json"
require "securerandom"
require "time"
require "uri"

require "faraday"
require "faraday/retry"
begin
  require "faraday/net_http_persistent"
rescue LoadError
  # Optional: keep-alive connections when faraday-net_http_persistent is installed.
end

require_relative "alpaca/version"
require_relative "alpaca/errors"
require_relative "alpaca/configuration"
require_relative "alpaca/http/response"
require_relative "alpaca/http/params"
require_relative "alpaca/http/auth"
require_relative "alpaca/http/connection"
require_relative "alpaca/model"
require_relative "alpaca/collection"
require_relative "alpaca/event_stream"
require_relative "alpaca/operation_registry"
require_relative "alpaca/resource"
require_relative "alpaca/client"
require_relative "alpaca/option_symbol"

module Alpaca
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
      reset_clients!
      configuration
    end

    # Restores default configuration (re-reading environment variables).
    def reset!
      @configuration = nil
      reset_clients!
    end

    private

    def reset_clients!
      @clients = {}
    end

    def memoized_client(name)
      (@clients ||= {})[name] ||= yield
    end
  end
end

require_relative "alpaca/trading"
require_relative "alpaca/broker"
require_relative "alpaca/market_data"
