require "bundler/setup"

require 'simplecov'
SimpleCov.start do
  add_filter '/spec'
  minimum_coverage 100
end

require "alpaca/trade/api"
require 'byebug'

require 'vcr'
VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  # Adding a few filters to avoid leaking sensitive data
  c.filter_sensitive_data('<KEY ID>') do |interaction|
    interaction.request.headers['Apca-Api-Key-Id'].first
  end
  c.filter_sensitive_data('<KEY SECRET>') do |interaction|
    interaction.request.headers['Apca-Api-Secret-Key'].first
  end
  c.filter_sensitive_data('<ID>') do |interaction|
    if interaction.response.status.code == 200
      JSON.parse(interaction.response.body)["id"]
    end
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
