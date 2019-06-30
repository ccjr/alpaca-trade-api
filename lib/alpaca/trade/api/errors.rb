module Alpaca
  module Trade
    module Api
      class Error < StandardError; end
      class UnauthorizedError < Error; end
    end
  end
end
