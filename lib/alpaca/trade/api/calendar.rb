# frozen_string_literal: true

module Alpaca
  module Trade
    module Api
      class Calendar
        attr_reader :date, :open, :close

        def initialize(json)
          @date = json['date']
          @open = json['open']
          @close = json['close']
        end
      end
    end
  end
end
