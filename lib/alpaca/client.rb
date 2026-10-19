# frozen_string_literal: true

module Alpaca
  # Shared behaviour for the Trading, Broker and Market Data clients.
  class Client
    attr_reader :connection, :config

    def initialize(base_url:, auth:, config:, &faraday)
      @config = config
      @connection = HTTP::Connection.new(base_url: base_url, auth: auth, config: config, &faraday)
    end

    def base_url = connection.base_url

    def inspect = "#<#{self.class.name} #{base_url}>"

    private

    def resource(name, klass, **)
      @resources ||= {}
      @resources[name] ||= klass.new(self, **)
    end
  end
end
