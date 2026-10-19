# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  enable_coverage :branch
  # Only gate on full runs; `rspec spec/some/dir` would otherwise fail on untouched code.
  minimum_coverage line: 95 if ENV["CI"] || ARGV.none? { |arg| arg.start_with?("spec/") }
end

require "alpaca"
require "webmock/rspec"

Dir[File.join(__dir__, "support", "**", "*.rb")].sort.each { |file| require file }

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include ApiHelpers

  config.before do
    Alpaca.reset!
    %w[APCA_API_KEY_ID APCA_API_SECRET_KEY ALPACA_API_KEY_ID ALPACA_API_SECRET_KEY APCA_API_OAUTH_TOKEN
      APCA_API_BASE_URL APCA_BROKER_CLIENT_ID APCA_BROKER_CLIENT_SECRET APCA_BROKER_API_KEY_ID
      APCA_BROKER_API_SECRET_KEY APCA_BROKER_SANDBOX APCA_DATA_FEED].each { |name| ENV.delete(name) }
    # Retries sleep; keep the suite fast unless a spec opts back in.
    Alpaca.configuration.max_retries = 0
  end
end
