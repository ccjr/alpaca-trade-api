module Alpaca
  module Trade
    module Api

      class Bar
        attr_reader :time, :open, :high, :low, :close, :volume

        def initialize(json)
          @time = Time.at(json['t'])
          @open = json['o']
          @high = json['h']
          @low = json['l']
          @close = json['c']
          @volume = json['v']
        end
      end

    end
  end
end
