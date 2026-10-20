# frozen_string_literal: true

RSpec.describe "Broker funding" do
  let(:client) { Alpaca::Broker::Client.new(key_id: "k", secret_key: "s") }
  let(:account_id) { "acc-1" }
  let(:accounts_url) { "#{BROKER_SANDBOX}/v1/accounts/#{account_id}" }

  it "manages ACH relationships" do
    rel = {"id" => "r1", "account_id" => account_id, "status" => "QUEUED", "bank_account_type" => "CHECKING"}
    stub_json(:get, "#{accounts_url}/ach_relationships", [rel], query: {"statuses" => "QUEUED,APPROVED"})
    expect(client.ach_relationships.list(account_id, statuses: %w[QUEUED APPROVED]).first.status).to eq(:QUEUED)

    stub_json(:post, "#{accounts_url}/ach_relationships", rel, request_body: json_body(
      account_owner_name: "Jane Doe", bank_account_type: "CHECKING", bank_account_number: "32131231abc",
      bank_routing_number: "121000358"
    ))
    created = client.ach_relationships.create(account_id, account_owner_name: "Jane Doe", bank_account_type: :CHECKING,
      bank_account_number: "32131231abc", bank_routing_number: "121000358")
    expect(created.id).to eq("r1")

    stub_request(:delete, "#{accounts_url}/ach_relationships/r1").to_return(status: 204)
    expect(client.ach_relationships.delete(account_id, "r1")).to be(true)

    stub_json(:get, "#{accounts_url}/ach_relationships", nil)
    expect(client.ach_relationships.list(account_id)).to eq([])
  end

  it "manages recipient banks" do
    bank = {"id" => "b1", "name" => "Chase", "bank_code" => "021000021", "bank_code_type" => "ABA", "status" => "QUEUED"}
    stub_json(:get, "#{accounts_url}/recipient_banks", [bank], query: {"status" => "ACTIVE"})
    expect(client.recipient_banks.list(account_id, status: :ACTIVE).first.bank_code_type).to eq(:ABA)

    stub_json(:post, "#{accounts_url}/recipient_banks", bank,
      request_body: json_body(name: "Chase", bank_code: "021000021", bank_code_type: "ABA", account_number: "123"))
    expect(client.recipient_banks.create(account_id, name: "Chase", bank_code: "021000021", bank_code_type: :ABA,
      account_number: "123").id).to eq("b1")

    stub_request(:delete, "#{accounts_url}/recipient_banks/b1").to_return(status: 204)
    expect(client.recipient_banks.delete(account_id, "b1")).to be(true)

    stub_json(:get, "#{accounts_url}/recipient_banks", nil)
    expect(client.recipient_banks.list(account_id)).to eq([])
  end

  it "creates, lists and cancels transfers" do
    transfer = {"id" => "t1", "type" => "ach", "status" => "QUEUED", "amount" => "500", "direction" => "INCOMING",
                "created_at" => "2026-10-19T14:00:00Z"}
    stub_json(:post, "#{accounts_url}/transfers", transfer, request_body: json_body(
      transfer_type: "ach", relationship_id: "r1", amount: "500", direction: "INCOMING"
    ))
    created = client.transfers.create(account_id, transfer_type: :ach, relationship_id: "r1", amount: BigDecimal(500),
      direction: :INCOMING)
    expect(created).to have_attributes(amount: BigDecimal(500), direction: :INCOMING, type: :ach)

    stub_json(:get, "#{accounts_url}/transfers", [transfer], query: {"direction" => "INCOMING", "limit" => "10"})
    expect(client.transfers.list(account_id, direction: :INCOMING, limit: 10).to_a.size).to eq(1)

    stub_request(:delete, "#{accounts_url}/transfers/t1").to_return(status: 200)
    expect(client.transfers.cancel(account_id, "t1")).to be(true)

    stub_json(:get, "#{accounts_url}/transfers", nil, query: {"limit" => "100"})
    expect(client.transfers.list(account_id).to_a).to eq([])
  end

  it "paginates offset-based transfer lists" do
    transfer = {"type" => "ach", "status" => "QUEUED", "amount" => "10", "direction" => "INCOMING"}
    stub_json(:get, "#{accounts_url}/transfers", [transfer.merge("id" => "t1"), transfer.merge("id" => "t2")],
      query: {"limit" => "2"})
    stub_json(:get, "#{accounts_url}/transfers", [transfer.merge("id" => "t3")],
      query: {"limit" => "2", "offset" => "2"})

    expect(client.transfers.list(account_id, limit: 2).map(&:id)).to eq(%w[t1 t2 t3])
    expect { client.transfers.list(account_id, limit: 0) }.to raise_error(ArgumentError, "limit must be positive")
  end

  describe "journals" do
    let(:journal) do
      {"id" => "j1", "entry_type" => "JNLC", "from_account" => "firm", "to_account" => account_id, "status" => "executed",
       "net_amount" => "50", "settle_date" => "2026-10-20", "system_date" => "2026-10-19"}
    end

    it "lists, finds, creates and cancels journals" do
      stub_json(:get, "#{BROKER_SANDBOX}/v1/journals", [journal], query: {"entry_type" => "JNLC", "status" => "executed"})
      expect(client.journals.list(entry_type: :JNLC, status: :executed).first.net_amount).to eq(BigDecimal(50))

      stub_json(:get, "#{BROKER_SANDBOX}/v1/journals/j1", journal)
      expect(client.journals.find("j1").settle_date).to eq(Date.new(2026, 10, 20))

      stub = stub_request(:post, "#{BROKER_SANDBOX}/v1/journals")
        .with(headers: {"Idempotency-Key" => "idem"},
          body: json_body(entry_type: "JNLC", from_account: "firm", to_account: account_id, amount: "50"))
        .to_return(status: 200, body: JSON.generate(journal), headers: {"Content-Type" => "application/json"})
      expect(client.journals.create(entry_type: :JNLC, from_account: "firm", to_account: account_id, amount: BigDecimal(50),
        idempotency_key: "idem").id).to eq("j1")
      expect(stub).to have_been_requested

      stub_request(:delete, "#{BROKER_SANDBOX}/v1/journals/j1").to_return(status: 204)
      expect(client.journals.cancel("j1")).to be(true)

      stub_json(:get, "#{BROKER_SANDBOX}/v1/journals", nil)
      expect(client.journals.list).to eq([])
    end

    it "creates batch and reverse batch journals" do
      stub_json(:post, "#{BROKER_SANDBOX}/v1/journals/batch", [journal, journal.merge("error_message" => "bad account")],
        request_body: json_body(entry_type: "JNLC", from_account: "firm", entries: [{to_account: "a", amount: "1"}]))
      results = client.journals.batch(from_account: "firm", entries: [{to_account: "a", amount: "1"}])
      expect(results.map(&:error_message)).to eq([nil, "bad account"])

      stub_json(:post, "#{BROKER_SANDBOX}/v1/journals/reverse_batch", [journal],
        request_body: json_body(entry_type: "JNLC", to_account: "firm", entries: [{from_account: "a", amount: "1"}]))
      expect(client.journals.reverse_batch(to_account: "firm", entries: [{from_account: "a", amount: "1"}]).size).to eq(1)

      stub_json(:post, "#{BROKER_SANDBOX}/v1/journals/batch", nil)
      expect(client.journals.batch(from_account: "firm", entries: [])).to eq([])
      stub_json(:post, "#{BROKER_SANDBOX}/v1/journals/reverse_batch", nil)
      expect(client.journals.reverse_batch(to_account: "firm", entries: [])).to eq([])
    end
  end

  describe "instant funding" do
    let(:base) { "#{BROKER_SANDBOX}/v1/instant_funding" }
    let(:funding) do
      {"id" => "if1", "account_no" => "123", "source_account_no" => "firm", "amount" => "100", "status" => "PENDING",
       "deadline" => "2026-10-21"}
    end
    let(:settlement) { {"id" => "s1", "status" => "PENDING", "total_amount" => "100"} }

    it "creates, lists, finds and cancels" do
      stub_json(:get, base, [funding], query: {"status" => "PENDING", "limit" => "100"})
      expect(client.instant_funding.list(status: :PENDING).first.deadline).to eq(Date.new(2026, 10, 21))

      stub_json(:get, "#{base}/if1", funding)
      expect(client.instant_funding.find("if1").amount).to eq(BigDecimal(100))

      stub_json(:post, base, funding, request_body: json_body(account_no: "123", source_account_no: "firm", amount: "100"))
      expect(client.instant_funding.create(account_no: "123", source_account_no: "firm", amount: BigDecimal(100)).id).to eq("if1")

      stub_request(:delete, "#{base}/if1").to_return(status: 204)
      expect(client.instant_funding.cancel("if1")).to be(true)

      stub_json(:get, base, nil, query: {"limit" => "100"})
      expect(client.instant_funding.list.to_a).to eq([])
    end

    it "reads limits and reports" do
      stub_json(:get, "#{base}/limits", {"amount_limit" => "1000000", "amount_available" => "900000"})
      expect(client.instant_funding.limits.amount_available).to eq(BigDecimal(900_000))

      stub_json(:get, "#{base}/limits/accounts", [{"account_no" => "123", "amount_limit" => "1000"}],
        query: {"account_numbers" => "123,456"})
      expect(client.instant_funding.account_limits(%w[123 456]).first.amount_limit).to eq(BigDecimal(1000))

      stub_json(:get, "#{base}/reports", [{"account_no" => "123", "total_amount_owed" => "10",
                                           "instant_funding_transfers" => [funding]}], query: {"report_type" => "summary"})
      report = client.instant_funding.reports(report_type: "summary").first
      expect(report.instant_funding_transfers.first).to be_a(Alpaca::InstantFunding)

      stub_json(:get, "#{base}/limits/accounts", nil, query: {"account_numbers" => "1"})
      expect(client.instant_funding.account_limits("1")).to eq([])
      stub_json(:get, "#{base}/reports", nil)
      expect(client.instant_funding.reports).to eq([])
    end

    it "manages settlements" do
      stub_json(:get, "#{base}/settlements", {"settlements" => [settlement]}, query: {"statuses" => "PENDING"})
      expect(client.instant_funding.settlements(statuses: "PENDING").first.total_amount).to eq(BigDecimal(100))

      stub_json(:get, "#{base}/settlements/s1", settlement)
      expect(client.instant_funding.settlement("s1").id).to eq("s1")

      stub_json(:post, "#{base}/settlements", settlement, request_body: json_body(transfers: [{instant_transfer_id: "if1"}]))
      expect(client.instant_funding.create_settlement(transfers: [{instant_transfer_id: "if1"}]).id).to eq("s1")

      stub_json(:get, "#{base}/settlements", nil)
      expect(client.instant_funding.settlements).to eq([])
    end
  end

  describe "JIT" do
    it "manages settlements, ledgers, limits and reports" do
      settlement = {"id" => "s1", "status" => "PENDING", "asset_class" => "us_equity", "total_amount" => "5"}
      stub_json(:get, "#{BROKER_SANDBOX}/v1/jit/settlements", {"settlements" => [settlement]})
      expect(client.jit.settlements.first.asset_class).to eq(:us_equity)
      stub_json(:get, "#{BROKER_SANDBOX}/v1/jit/settlements", nil)
      expect(client.jit.settlements).to eq([])

      stub_json(:get, "#{BROKER_SANDBOX}/v1/jit/settlements/s1", settlement)
      expect(client.jit.settlement("s1").id).to eq("s1")

      stub_json(:post, "#{BROKER_SANDBOX}/v1/jit/settlements", settlement, request_body: json_body(
        accounts: [{account_number: "123", amount: "5"}], asset_class: "us_equity", currency: "USD"
      ))
      expect(client.jit.create_settlement(accounts: [{account_number: "123", amount: "5"}], asset_class: :us_equity,
        currency: "USD").id).to eq("s1")

      stub_json(:get, "#{BROKER_SANDBOX}/v1/transfers/jit/ledgers", [{"id" => "l1", "ledger_name" => "main"}])
      expect(client.jit.ledgers.first.ledger_name).to eq("main")
      stub_json(:get, "#{BROKER_SANDBOX}/v1/transfers/jit/ledgers", nil)
      expect(client.jit.ledgers).to eq([])

      stub_json(:get, "#{BROKER_SANDBOX}/v1/transfers/jit/l1/balances", {"id" => "l1", "ending_balance" => "10.5"},
        query: {"start_date" => "2026-10-01"})
      expect(client.jit.ledger_balances("l1", start_date: Date.new(2026, 10, 1)).ending_balance).to eq(BigDecimal("10.5"))

      stub_json(:get, "#{BROKER_SANDBOX}/v1/transfers/jit/limits", {"daily_net_limit" => "1000"})
      expect(client.jit.limits.daily_net_limit).to eq(BigDecimal(1000))

      stub_json(:get, "#{BROKER_SANDBOX}/v1/transfers/jit/reports", {"detail" => "csv"},
        query: {"report_type" => "detail", "system_date" => "2026-10-19"})
      expect(client.jit.reports(report_type: :detail, system_date: Date.new(2026, 10, 19))).to eq("detail" => "csv")
    end
  end

  describe "funding wallets" do
    let(:wallet_url) { "#{BROKER_SANDBOX}/v1beta/accounts/#{account_id}/funding_wallet" }
    let(:transfer) { {"id" => "ft1", "direction" => "outgoing", "total_amount" => "99.5", "status" => "pending"} }

    it "creates and reads wallets" do
      stub_json(:get, wallet_url, {"account_id" => account_id, "status" => "active"})
      expect(client.funding_wallets.find(account_id).status).to eq(:active)

      stub_json(:post, wallet_url, {"account_id" => account_id, "status" => "pending"})
      expect(client.funding_wallets.create(account_id).status).to eq(:pending)

      stub_json(:post, "#{BROKER_SANDBOX}/v1beta/accounts/funding_wallet", {"funding_wallets" => [{"account_id" => "a"}]},
        request_body: json_body(account_ids: %w[a]))
      expect(client.funding_wallets.batch_create("a").map(&:account_id)).to eq(%w[a])
      stub_json(:post, "#{BROKER_SANDBOX}/v1beta/accounts/funding_wallet", nil)
      expect(client.funding_wallets.batch_create([])).to eq([])

      stub_json(:get, "#{wallet_url}/funding_details", {"details" => []}, query: {"currency" => "EUR"})
      expect(client.funding_wallets.funding_details(account_id, currency: "EUR")).to eq("details" => [])
    end

    it "manages the recipient bank" do
      bank = {"id" => "rb1", "iban" => "DE89", "currency" => "EUR"}
      stub_json(:get, "#{wallet_url}/recipient_bank", bank)
      expect(client.funding_wallets.recipient_bank(account_id).iban).to eq("DE89")

      stub_json(:post, "#{wallet_url}/recipient_bank", bank, request_body: json_body(
        account_number: "1", bank_country: "DE", bank_name: "Bank", city: "Berlin", currency: "EUR", street_address: "x"
      ))
      expect(client.funding_wallets.create_recipient_bank(account_id, account_number: "1", bank_country: "DE",
        bank_name: "Bank", city: "Berlin", currency: "EUR", street_address: "x").id).to eq("rb1")

      stub_request(:delete, "#{wallet_url}/recipient_bank").to_return(status: 200)
      expect(client.funding_wallets.delete_recipient_bank(account_id)).to be(true)
    end

    it "lists transfers, withdraws and simulates deposits" do
      stub_json(:get, "#{wallet_url}/transfers", {"transfers" => [transfer]})
      expect(client.funding_wallets.transfers(account_id).first.total_amount).to eq(BigDecimal("99.5"))
      stub_json(:get, "#{wallet_url}/transfers", nil)
      expect(client.funding_wallets.transfers(account_id)).to eq([])

      stub_json(:get, "#{wallet_url}/transfers/ft1", transfer)
      expect(client.funding_wallets.transfer(account_id, "ft1").id).to eq("ft1")

      stub_json(:post, "#{wallet_url}/withdrawal", transfer, request_body: json_body(usd_amount: "100", desired_currency: "EUR"))
      expect(client.funding_wallets.withdraw(account_id, usd_amount: BigDecimal(100), desired_currency: "EUR").id).to eq("ft1")

      stub_json(:post, "#{BROKER_SANDBOX}/v1beta/demo/banking/funding", {"amount" => "25", "currency" => "EUR"},
        request_body: json_body(amount: "25", currency: "EUR"))
      expect(client.funding_wallets.demo_deposit(amount: BigDecimal(25), currency: "EUR").amount).to eq(BigDecimal(25))
    end
  end
end
