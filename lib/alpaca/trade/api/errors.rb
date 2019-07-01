module Alpaca
  module Trade
    module Api
      class Error < StandardError; end
      class RateLimitedError < Error; end
      class UnauthorizedError < Error; end
    end
  end
end
