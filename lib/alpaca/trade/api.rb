require "alpaca/trade/api/version"
require "alpaca/trade/api/configuration"

require "alpaca/trade/api/account"
require "alpaca/trade/api/asset"
require "alpaca/trade/api/client"

require 'json'

module Alpaca
  module Trade
    module Api
      class Error < StandardError; end

      class << self
        def configuration
          @configuration ||= Alpaca::Trade::Api::Configuration.new
        end

        def configure
          yield(configuration)
        end

        def reset
          @configuration = Alpaca::Trade::Api::Configuration.new
        end
      end

    end
  end
end
