# frozen_string_literal: true

RSpec.describe Alpaca::MarketData::CorporateActionEvents do
  let(:client) { Alpaca::MarketData::Client.new(key_id: "KEY", secret_key: "SECRET") }
  let(:example_events) { openapi_example(:market_data, "/v1beta1/events/corporate-actions").then { |e| e } }

  it "streams corporate action changes" do
    events = [{"action" => "insert", "at" => "2026-03-20T18:00:00.000000Z", "event_id" => "01K",
               "event_type" => "cash_dividend_corporateaction_event", "region" => "us",
               "ca" => {"symbol" => "AAPL", "rate" => "0.26"}}]
    stub_request(:get, "#{DATA}/v1beta1/events/corporate-actions")
      .with(query: {"since" => "2026-03-20T00:00:00Z", "until" => "2026-03-21T00:00:00Z"})
      .to_return(status: 200, body: "data: #{JSON.generate(events)}\n\n")

    result = client.corporate_action_events(since: Time.utc(2026, 3, 20), until: Time.utc(2026, 3, 21)).to_a

    expect(result.first).to be_a(Alpaca::MarketData::CorporateActionEvent)
    expect(result.first).to have_attributes(action: :insert, region: "us", event_id: "01K")
    expect(result.first.ca["rate"]).to eq("0.26")
  end
end
