# frozen_string_literal: true

require_relative "lib/alpaca/version"

Gem::Specification.new do |spec|
  spec.name = "alpaca-trade-api"
  spec.version = Alpaca::VERSION
  spec.authors = ["Cloves Carneiro Jr"]
  spec.email = ["ccarneiroj@gmail.com"]

  spec.summary = "Ruby client for the Alpaca Trading, Broker and Market Data APIs."
  spec.description = "Complete Ruby client for Alpaca (alpaca.markets): Trading, Broker and Market Data " \
    "REST APIs with automatic pagination, safe retries and BigDecimal values, plus optional " \
    "WebSocket and SSE streaming."
  spec.homepage = "https://github.com/ccjr/alpaca-trade-api"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE.txt"]
    .reject { |path| path == "lib/alpaca/openapi_coverage.rb" }
  spec.require_paths = ["lib"]

  spec.add_dependency "bigdecimal", ">= 3.1"
  spec.add_dependency "faraday", ">= 2.9", "< 3"
  spec.add_dependency "faraday-retry", "~> 2.2"
end
