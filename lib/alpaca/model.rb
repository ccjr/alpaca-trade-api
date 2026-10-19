# frozen_string_literal: true

module Alpaca
  # Base class for API objects.
  #
  # Declared attributes are coerced to Ruby types; every other field returned by
  # the API is kept as-is and stays reachable through #[] and reader methods, so
  # fields Alpaca adds later work without a gem upgrade.
  #
  #   class Order < Alpaca::Model
  #     attribute :qty, :decimal
  #     attribute :submitted_at, :time
  #     attribute :legs, [Order]
  #   end
  class Model
    TYPES = %i[string integer decimal boolean time date symbol raw].freeze
    # Methods an API field must not shadow; such fields stay reachable through #[].
    RESERVED = %i[
      class hash freeze frozen? object_id send public_send respond_to? is_a? kind_of? instance_of?
      nil? dup clone itself then tap method methods inspect to_s display
      response keys key? to_h deconstruct_keys
    ].freeze

    class << self
      def attribute(name, type = :raw)
        name = name.to_s
        validate_type!(type)
        own_attributes[name] = type
        define_method(name) { @attributes[name] } unless RESERVED.include?(name.to_sym)
        define_method(:"#{name}?") { !!@attributes[name] } if type == :boolean
      end

      def attributes
        inherited = (superclass < Model) ? superclass.attributes : {}
        inherited.merge(own_attributes)
      end

      # Builds a model, an array of models, or nil from parsed JSON.
      def build(value, response: nil)
        case value
        when nil then nil
        when Array then value.map { |item| build(item, response: response) }
        when self then value
        else new(value, response: response)
        end
      end

      def coerce(type, value)
        return nil if value.nil?

        case type
        when Array then Array(value).map { |item| coerce(type.first, item) }
        when Class then type.build(value)
        when :decimal then decimal(value)
        when :integer then value.is_a?(Integer) ? value : Integer(value.to_s, 10)
        when :boolean then [true, "true"].include?(value)
        when :time then time(value)
        when :date then (value == "") ? nil : Date.iso8601(value.to_s)
        when :symbol then (value == "") ? nil : value.to_s.to_sym
        when :string then value.to_s
        else value
        end
      end

      private

      def own_attributes = (@own_attributes ||= {})

      def validate_type!(type)
        return if type.is_a?(Class) && type < Model
        return if type.is_a?(Array) && type.size == 1 && (TYPES.include?(type.first) || type.first < Model)
        return if TYPES.include?(type)

        raise ArgumentError, "unknown attribute type #{type.inspect}"
      end

      def decimal(value)
        case value
        when BigDecimal then value
        when "" then nil
        when Integer then BigDecimal(value)
        when Float then BigDecimal(value, Float::DIG)
        else BigDecimal(value.to_s)
        end
      end

      def time(value)
        return value if value.is_a?(Time)
        return nil if value == ""

        Time.iso8601(value.to_s)
      rescue ArgumentError
        Time.parse(value.to_s)
      end
    end

    # The HTTP response this object came from (status, headers, rate limit).
    attr_reader :response

    def initialize(attributes = nil, response: nil, **fields)
      @response = response
      declared = self.class.attributes
      @attributes = (attributes || {}).merge(fields).each_with_object({}) do |(key, value), out|
        key = key.to_s
        type = declared[key]
        out[key] = type ? self.class.coerce(type, value) : value
      end
      freeze
    end

    def [](key) = @attributes[key.to_s]

    def key?(key) = @attributes.key?(key.to_s)

    def keys = @attributes.keys

    # Deep conversion to a Hash with symbol keys.
    def to_h
      @attributes.to_h { |key, value| [key.to_sym, unwrap(value)] }
    end

    def deconstruct_keys(keys)
      keys ? keys.to_h { |key| [key, unwrap(@attributes[key.to_s])] } : to_h
    end

    def ==(other) = other.class == self.class && other.attributes_hash == attributes_hash

    alias_method :eql?, :==

    def hash = [self.class, attributes_hash].hash

    def respond_to_missing?(name, include_private = false)
      @attributes.key?(name.to_s) || super
    end

    def method_missing(name, *args)
      return @attributes[name.to_s] if args.empty? && @attributes.key?(name.to_s)

      super
    end

    def inspect
      fields = @attributes.map { |key, value| "#{key}=#{value.inspect}" }.join(" ")
      "#<#{self.class.name} #{fields}>"
    end

    protected

    def attributes_hash = @attributes

    private

    def unwrap(value)
      case value
      when Model then value.to_h
      when Array then value.map { |item| unwrap(item) }
      when Hash then value.to_h { |key, item| [key.to_sym, unwrap(item)] }
      else value
      end
    end
  end
end
