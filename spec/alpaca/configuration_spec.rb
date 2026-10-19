# frozen_string_literal: true

RSpec.describe Alpaca::Configuration do
  it "reads APCA_* environment variables" do
    ENV["APCA_API_KEY_ID"] = "k"
    ENV["APCA_API_SECRET_KEY"] = "s"
    ENV["APCA_API_BASE_URL"] = "https://api.alpaca.markets"
    ENV["APCA_DATA_FEED"] = "sip"
    ENV["APCA_BROKER_SANDBOX"] = "false"
    config = described_class.new
    expect(config).to have_attributes(key_id: "k", secret_key: "s", paper: false, data_feed: :sip, broker_sandbox: false)
  end

  it "falls back to the 0.x ALPACA_* names and defaults to paper" do
    ENV["ALPACA_API_KEY_ID"] = "old"
    ENV["APCA_API_KEY_ID"] = ""
    config = described_class.new
    expect(config.key_id).to eq("old")
    expect(config.paper).to be(true)
    expect(config.broker_sandbox).to be(true)
    expect(config.user_agent).to eq("alpaca-trade-api-ruby/#{Alpaca::VERSION}")
  end

  it "is configurable globally" do
    Alpaca.configure { |c| c.timeout = 5 }
    expect(Alpaca.configuration.timeout).to eq(5)
    Alpaca.reset!
    expect(Alpaca.configuration.timeout).to eq(30)
  end
end
