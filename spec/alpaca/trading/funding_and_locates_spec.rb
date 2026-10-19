# frozen_string_literal: true

RSpec.describe "Trading crypto funding, tokenization and locates" do
  let(:client) { trading_client }

  describe Alpaca::Trading::CryptoFunding do
    let(:funding) { client.crypto_funding }
    let(:transfer) do
      {"id" => "t1", "asset" => "USDC", "chain" => "ETH", "direction" => "OUTGOING", "status" => "PROCESSING",
       "amount" => "10.5", "network_fee" => "0.01", "to_address" => "0xabc", "created_at" => "2026-10-19T14:00:00Z"}
    end
    let(:whitelisted) { {"id" => "w1", "asset" => "USDC", "address" => "0xabc", "chain" => "ETH", "status" => "PENDING"} }

    it "lists wallets and transfers whether the API returns one object or many" do
      stub_json(:get, "#{PAPER}/v2/wallets", {"address" => "0x1", "chain" => "ETH"}, query: {"asset" => "USDC"})
      expect(funding.wallets(asset: "USDC").map(&:address)).to eq(["0x1"])

      stub_json(:get, "#{PAPER}/v2/wallets/transfers", [transfer, transfer])
      expect(funding.transfers.map(&:amount)).to eq([BigDecimal("10.5")] * 2)

      stub_json(:get, "#{PAPER}/v2/wallets/transfers/t1", transfer)
      expect(funding.transfer("t1")).to have_attributes(direction: :OUTGOING, network_fee: BigDecimal("0.01"))
    end

    it "manages whitelisted addresses" do
      stub_json(:get, "#{PAPER}/v2/wallets/whitelists", [whitelisted])
      expect(funding.whitelisted_addresses.first.status).to eq(:PENDING)

      stub_json(:post, "#{PAPER}/v2/wallets/whitelists", whitelisted,
        request_body: json_body(address: "0xabc", asset: "USDC", chain: "ETH"))
      expect(funding.create_whitelisted_address(address: "0xabc", asset: "USDC", chain: "ETH").id).to eq("w1")

      stub_request(:patch, "#{PAPER}/v2/wallets/whitelists/w1/travel-rule-info")
        .with(body: json_body(travel_rule_info: {beneficiary_is_self_hosted: true})).to_return(status: 200)
      expect(funding.update_travel_rule_info("w1", {beneficiary_is_self_hosted: true})).to be(true)

      stub_request(:delete, "#{PAPER}/v2/wallets/whitelists/w1").to_return(status: 200)
      expect(funding.delete_whitelisted_address("w1")).to be(true)
    end

    it "estimates fees and searches VASPs" do
      stub_json(:get, "#{PAPER}/v2/wallets/fees/estimate", {"fee" => "0.5", "network_fee" => "0.1"},
        query: {"asset" => "USDC", "amount" => "10"})
      expect(funding.fee_estimate(asset: "USDC", amount: 10).fee).to eq(BigDecimal("0.5"))

      stub_json(:get, "#{PAPER}/v2/wallets/travel-rule/vasps", {"vasps" => [{"id" => "v1", "name" => "Coinbase"}],
                                                                "total" => 1}, query: {"q" => "coinbase"})
      expect(funding.search_vasps(q: "coinbase").vasps.first.name).to eq("Coinbase")
    end
  end

  describe Alpaca::Trading::Tokenization do
    let(:tokenization) { client.tokenization }
    let(:request) do
      {"tokenization_request_id" => "tr1", "type" => "mint", "status" => "pending", "issuer" => "xstocks",
       "network" => "solana", "underlying_symbol" => "AAPL", "token_symbol" => "AAPLx", "qty" => "1.5",
       "wallet_address" => "So1", "created_at" => "2026-10-19T14:00:00Z"}
    end

    it "mints with an idempotency key" do
      stub = stub_request(:post, "#{PAPER}/v2/tokenization/mint")
        .with(headers: {"Idempotency-Key" => "idem-1"},
          body: json_body(underlying_symbol: "AAPL", qty: "1.5", issuer: "xstocks", network: "solana", wallet_address: "So1"))
        .to_return(status: 200, body: JSON.generate(request), headers: {"Content-Type" => "application/json"})
      result = tokenization.mint(underlying_symbol: "AAPL", qty: BigDecimal("1.5"), issuer: "xstocks", network: "solana",
        wallet_address: "So1", idempotency_key: "idem-1")
      expect(stub).to have_been_requested
      expect(result.id).to eq("tr1")
      expect(result.qty).to eq(BigDecimal("1.5"))
    end

    it "lists and finds requests" do
      stub_json(:get, "#{PAPER}/v2/tokenization/requests", [request], query: {"status" => "pending"})
      expect(tokenization.requests(status: :pending).first.status).to eq(:pending)

      stub_json(:get, "#{PAPER}/v2/tokenization/requests/tr1", request)
      expect(tokenization.find("tr1").token_symbol).to eq("AAPLx")

      stub_json(:get, "#{PAPER}/v2/tokenization/requests:by_client_request_id", request,
        query: {"client_request_id" => "mine"})
      expect(tokenization.find_by_client_request_id("mine").id).to eq("tr1")

      stub_json(:get, "#{PAPER}/v2/tokenization/requests", nil)
      expect(tokenization.requests).to eq([])
    end
  end

  describe Alpaca::Trading::Locates do
    let(:locates) { client.locates }
    let(:locate) do
      {"id" => "l1", "symbol" => "GME", "status" => "filled", "all_or_none" => false, "requested_qty" => 100,
       "located_qty" => 100, "located_price" => "0.05", "total_fee" => "5", "created_at" => "2026-10-19T14:00:00Z"}
    end

    it "pages through locates" do
      stub_json(:get, "#{PAPER}/v1/locates", {"locates" => [locate], "next_page_token" => "p2"}, query: {"symbol" => "GME"})
      stub_json(:get, "#{PAPER}/v1/locates", {"locates" => [locate], "next_page_token" => ""},
        query: {"symbol" => "GME", "page_token" => "p2"})
      expect(locates.list(symbol: "GME").map(&:located_qty)).to eq([100, 100])
    end

    it "creates, finds and quotes" do
      stub = stub_request(:post, "#{PAPER}/v1/locates")
        .with(headers: {"Idempotency-Key" => "k"}, body: json_body(symbol: "GME", qty: 100, limit_price: "0.1"))
        .to_return(status: 201, body: JSON.generate(locate), headers: {"Content-Type" => "application/json"})
      expect(locates.create(symbol: "GME", qty: 100, limit_price: BigDecimal("0.1"), idempotency_key: "k").id).to eq("l1")
      expect(stub).to have_been_requested

      stub_json(:get, "#{PAPER}/v1/locates/l1", locate)
      expect(locates.find("l1").total_fee).to eq(BigDecimal(5))

      stub_json(:get, "#{PAPER}/v1/locates/quotes",
        {"quotes" => [{"symbol" => "GME", "available_qty" => 500, "price" => "0.05", "quoted_at" => "2026-10-19T14:00:00Z"}],
         "errors" => [{"symbol" => "ZZZZ", "code" => "symbol_not_found", "message" => "not found"}]},
        query: {"symbols" => "GME,ZZZZ"})
      quotes = locates.quotes(%w[GME ZZZZ])
      expect(quotes.quotes.first.available_qty).to eq(500)
      expect(quotes.errors.first["code"]).to eq("symbol_not_found")
    end
  end
end
