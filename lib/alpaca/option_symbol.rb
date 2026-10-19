# frozen_string_literal: true

module Alpaca
  # OCC option symbols, e.g. "AAPL270115C00190000":
  # root, expiration (YYMMDD), C/P, strike x 1000 padded to 8 digits.
  #
  #   Alpaca::OptionSymbol.build("AAPL", expiration: Date.new(2027, 1, 15), type: :call, strike: 190)
  #   # => "AAPL270115C00190000"
  #   Alpaca::OptionSymbol.parse("AAPL270115C00190000").strike # => 0.19e3
  OptionSymbol = Data.define(:root, :expiration, :type, :strike) do
    pattern = /\A([A-Z0-9.]{1,6})(\d{2})(\d{2})(\d{2})([CP])(\d{8})\z/

    define_singleton_method(:parse) do |symbol|
      match = pattern.match(symbol.to_s.strip.upcase.delete(" "))
      raise ArgumentError, "invalid OCC option symbol: #{symbol.inspect}" unless match

      new(
        root: match[1],
        expiration: Date.new(2000 + match[2].to_i, match[3].to_i, match[4].to_i),
        type: (match[5] == "C") ? :call : :put,
        strike: BigDecimal(match[6]) / 1000
      )
    end

    define_singleton_method(:build) do |root, expiration:, type:, strike:|
      new(root: root, expiration: expiration, type: type, strike: strike).to_s
    end

    define_singleton_method(:valid?) { |symbol| pattern.match?(symbol.to_s) }

    def initialize(root:, expiration:, type:, strike:)
      type = type.to_s.downcase.to_sym
      type = {c: :call, p: :put}.fetch(type, type)
      raise ArgumentError, "type must be :call or :put" unless %i[call put].include?(type)

      expiration = Date.iso8601(expiration) if expiration.is_a?(String)
      super(root: root.to_s.upcase, expiration: expiration, type: type, strike: BigDecimal(strike.to_s))
    end

    def call? = type == :call

    def put? = type == :put

    def to_s
      millis = (strike * 1000).to_i
      "#{root}#{expiration.strftime("%y%m%d")}#{call? ? "C" : "P"}#{millis.to_s.rjust(8, "0")}"
    end
  end
end
