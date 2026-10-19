# frozen_string_literal: true

RSpec.describe "Broker accounts, documents, KYC and activities" do
  let(:client) { Alpaca::Broker::Client.new(key_id: "k", secret_key: "s") }
  let(:account_id) { "acc-1" }
  let(:account) do
    {"id" => account_id, "account_number" => "123456789", "status" => "APPROVED", "crypto_status" => "ACTIVE",
     "currency" => "USD", "last_equity" => "1500.25", "created_at" => "2026-10-01T12:00:00Z",
     "account_type" => "trading", "enabled_assets" => ["us_equity"],
     "contact" => {"email_address" => "jane@example.com", "street_address" => ["20 N San Mateo Dr"], "city" => "San Mateo"},
     "identity" => {"given_name" => "Jane", "family_name" => "Doe", "date_of_birth" => "1990-01-01",
                    "liquid_net_worth_min" => "0", "funding_source" => ["employment_income"]},
     "disclosures" => {"is_control_person" => false, "employment_status" => "employed"},
     "agreements" => [{"agreement" => "customer_agreement", "signed_at" => "2026-10-01T12:00:00Z", "ip_address" => "127.0.0.1"}],
     "trading_configurations" => {"dtbp_check" => "both", "max_margin_multiplier" => "4"}}
  end

  describe Alpaca::Broker::Accounts do
    let(:accounts) { client.accounts }

    it "lists, finds, creates, updates and closes accounts" do
      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts", [account], query: {"query" => "doe", "entities" => "contact,identity"})
      listed = accounts.list(query: "doe", entities: %w[contact identity]).first
      expect(listed).to be_a(Alpaca::BrokerAccount)
      expect(listed.contact.street_address).to eq(["20 N San Mateo Dr"])
      expect(listed.identity.date_of_birth).to eq(Date.new(1990, 1, 1))
      expect(listed.identity.liquid_net_worth_min).to eq(BigDecimal(0))
      expect(listed.disclosures.employment_status).to eq(:employed)
      expect(listed.agreements.first.agreement).to eq(:customer_agreement)
      expect(listed.trading_configurations.max_margin_multiplier).to eq(BigDecimal(4))
      expect(listed.last_equity).to eq(BigDecimal("1500.25"))

      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/#{account_id}", account)
      expect(accounts.find(account_id).status).to eq(:APPROVED)

      stub_json(:post, "#{BROKER_SANDBOX}/v1/accounts", account,
        request_body: json_body(contact: {email_address: "jane@example.com"}, enabled_assets: ["us_equity"]))
      expect(accounts.create(contact: {email_address: "jane@example.com"}, enabled_assets: [:us_equity]).id).to eq(account_id)

      stub_json(:patch, "#{BROKER_SANDBOX}/v1/accounts/#{account_id}", account,
        request_body: json_body(trusted_contact: {given_name: "John"}))
      expect(accounts.update(account_id, trusted_contact: {given_name: "John"})).to be_a(Alpaca::BrokerAccount)

      stub_request(:post, "#{BROKER_SANDBOX}/v1/accounts/#{account_id}/actions/close").to_return(status: 204)
      expect(accounts.close(account_id)).to be(true)

      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts", nil)
      expect(accounts.list).to eq([])
    end

    it "requests and lists options approvals" do
      approval = {"id" => "ap1", "account_id" => account_id, "requested_level" => 2, "status" => "PENDING"}
      stub_json(:post, "#{BROKER_SANDBOX}/v1/accounts/#{account_id}/options/approval", approval, request_body: json_body(level: 2))
      expect(accounts.request_options(account_id, level: 2).requested_level).to eq(2)

      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/options/approvals",
        {"options_approvals" => [approval], "next_page_token" => "n"}, query: {"status" => "PENDING"})
      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/options/approvals",
        {"options_approvals" => [approval], "next_page_token" => nil}, query: {"status" => "PENDING", "page_token" => "n"})
      expect(accounts.options_approvals(status: "PENDING").map(&:status)).to eq(%i[PENDING PENDING])
    end

    it "pages bulk positions by page number" do
      position = {"symbol" => "AAPL", "qty" => "2"}
      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/positions",
        {"as_of" => "2026-10-19T00:00:00Z", "positions" => {"a1" => [position], "a2" => [position]}}, query: {"page" => "1"})
      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/positions", {"positions" => {}}, query: {"page" => "2"})
      positions = accounts.all_positions.to_a
      expect(positions.map(&:account_id)).to eq(%w[a1 a2])
      expect(positions.first.qty).to eq(BigDecimal(2))
    end

    it "lists IRA excess contributions" do
      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/ira_excess_contributions",
        [{"account_id" => account_id, "tax_year" => 2025, "total_contribution_amount" => "7500.5"}])
      expect(accounts.ira_excess_contributions.first.total_contribution_amount).to eq(BigDecimal("7500.5"))
    end
  end

  describe Alpaca::Broker::Documents do
    let(:documents) { client.documents }

    it "lists, downloads and uploads documents" do
      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/#{account_id}/documents",
        [{"id" => "d1", "type" => "account_statement", "date" => "2026-09-30", "name" => "Statement"}],
        query: {"type" => "account_statement", "start" => "2026-01-01"})
      doc = documents.list(account_id, type: :account_statement, start: Date.new(2026, 1, 1)).first
      expect(doc).to have_attributes(type: :account_statement, date: Date.new(2026, 9, 30))

      stub_request(:get, "#{BROKER_SANDBOX}/v1/accounts/#{account_id}/documents/d1/download")
        .with(headers: {"Accept" => "*/*"}).to_return(status: 200, body: "%PDF-1.7", headers: {"Content-Type" => "application/pdf"})
      expect(documents.download(account_id, "d1")).to eq("%PDF-1.7")

      stub_request(:get, "#{BROKER_SANDBOX}/v1/accounts/#{account_id}/documents/w8ben/w1/download")
        .to_return(status: 200, body: "%PDF-W8")
      expect(documents.download_w8ben(account_id, "w1")).to eq("%PDF-W8")

      stub = stub_request(:post, "#{BROKER_SANDBOX}/v1/accounts/#{account_id}/documents/upload")
        .with(body: json_body([{document_type: "identity_verification", mime_type: "image/png", content: "aGVsbG8="},
          {document_type: "w8ben", content: "already"}]))
        .to_return(status: 204)
      expect(documents.upload(account_id, [
        {document_type: :identity_verification, mime_type: "image/png", content_data: "hello"},
        {"document_type" => "w8ben", "content" => "already"}
      ])).to be(true)
      expect(stub).to have_been_requested
    end
  end

  describe Alpaca::Broker::KYC do
    let(:kyc) { client.kyc }

    it "reads and submits CIP" do
      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/#{account_id}/cip",
        {"id" => "cip1", "account_id" => account_id, "provider_name" => ["onfido"], "kyc" => {"result" => "clear"}})
      expect(kyc.cip(account_id).kyc).to eq("result" => "clear")

      stub = stub_request(:post, "#{BROKER_SANDBOX}/v1/accounts/#{account_id}/cip")
        .with(body: json_body(provider_name: ["onfido"], kyc: {result: "clear"})).to_return(status: 200)
      expect(kyc.submit_cip(account_id, provider_name: ["onfido"], kyc: {result: "clear"})).to be(true)
      expect(stub).to have_been_requested
    end

    it "drives the Onfido SDK flow" do
      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/#{account_id}/onfido/sdk/tokens", {"token" => "sdk-token"},
        query: {"platform" => "web"})
      expect(kyc.onfido_token(account_id, platform: :web)).to eq("sdk-token")

      stub = stub_request(:patch, "#{BROKER_SANDBOX}/v1/accounts/#{account_id}/onfido/sdk")
        .with(body: json_body(token: "sdk-token", outcome: "USER_COMPLETED")).to_return(status: 200)
      expect(kyc.update_onfido_outcome(account_id, token: "sdk-token", outcome: :USER_COMPLETED)).to be(true)
      expect(stub).to have_been_requested
    end
  end

  describe Alpaca::Broker::Activities do
    it "pages through activities across accounts" do
      activity = {"id" => "a::1", "account_id" => account_id, "activity_type" => "FILL", "qty" => "1"}
      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/activities", [activity],
        query: {"page_size" => "1", "account_id" => account_id})
      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/activities", [],
        query: {"page_size" => "1", "account_id" => account_id, "page_token" => "a::1"})
      result = client.activities.list(account_id: account_id, page_size: 1).to_a
      expect(result.map(&:account_id)).to eq([account_id])

      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/activities/DIV", [], query: {"page_size" => "100"})
      expect(client.activities.list("DIV").to_a).to eq([])
    end
  end
end
