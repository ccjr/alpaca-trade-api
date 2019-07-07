# frozen_string_literal: true

module Alpaca
  module Trade
    module Api
      class Clock
        attr_reader :timestamp, :open, :next_open, :next_close

        def initialize(json)
          @timestamp = json['timestamp']
          @open = json['open']
          @next_open = json['next_open']
          @next_close = json['next_close']
        end
      end
    end
  end
end
