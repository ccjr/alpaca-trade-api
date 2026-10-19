# frozen_string_literal: true

module Alpaca
  class Market < Model
    attribute :acronym, :string
    attribute :name, :string
    attribute :mic, :string
    attribute :bic, :string
    attribute :timezone, :string
  end

  # One market's clock (v3 /clock).
  class Clock < Model
    attribute :market, Market
    attribute :timestamp, :time
    attribute :is_market_day, :boolean
    attribute :phase, :symbol
    attribute :phase_until, :time
    attribute :next_market_open, :time
    attribute :next_market_close, :time

    def open? = phase == :core
  end

  class CalendarDay < Model
    attribute :date, :date
    attribute :settlement_date, :date
    %i[pre_start pre_end core_start core_end post_start post_end lunch_start lunch_end].each do |name|
      attribute name, :time
    end
  end

  # v3 /calendar/{market}: the market plus its trading days.
  class MarketCalendar < Model
    attribute :market, Market
    attribute :calendar, [CalendarDay]

    def days = calendar
  end
end
