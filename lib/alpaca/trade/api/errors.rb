# frozen_string_literal: true

module Alpaca
  module Trade
    module Api
      class Error < StandardError; end
      class InsufficientFunds < Error; end
      class InternalServerError < Error; end
      class InvalidActivityType < Error; end
      class InvalidOrderId < Error; end
      class InvalidRequest < Error; end
      class MissingParameters < Error; end
      class NoPositionForSymbol < Error; end
      class OrderNotCancelable < Error; end
      class RateLimitedError < Error; end
      class UnauthorizedError < Error; end
      class Unprocessable < Error; end
    end
  end
end
