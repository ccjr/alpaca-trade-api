# frozen_string_literal: true

module Alpaca
  module Trade
    module Api
      class Clock
        attr_reader :timestamp, :is_open, :next_open, :next_close

        def initialize(json)
          @timestamp = json['timestamp']
          @is_open = json['is_open']
          @next_open = json['next_open']
          @next_close = json['next_close']
        end
      end
    end
  end
end
