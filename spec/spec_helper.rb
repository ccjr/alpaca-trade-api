require "bundler/setup"
require "alpaca/trade/api"

require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.filter_sensitive_data('<KEY ID>') do |interaction|
    interaction.request.headers['Apca-Api-Key-Id'].first
  end
  c.filter_sensitive_data('<KEY SECRET>') do |interaction|
    interaction.request.headers['Apca-Api-Secret-Key'].first
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
