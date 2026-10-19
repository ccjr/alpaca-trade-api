# frozen_string_literal: true

module Alpaca
  class Position < Model
    attribute :symbol, :string
    attribute :asset_id, :string
    attribute :asset_class, :symbol
    attribute :exchange, :string
    attribute :side, :symbol
    attribute :asset_marginable, :boolean
    %i[
      qty qty_available avg_entry_price cost_basis current_price lastday_price change_today
      market_value unrealized_pl unrealized_plpc unrealized_intraday_pl unrealized_intraday_plpc
      swap_rate avg_entry_swap_rate prev_swap_rate
    ].each { |name| attribute name, :decimal }
    attribute :usd, :raw

    def long? = side == :long

    def short? = side == :short
  end
end
