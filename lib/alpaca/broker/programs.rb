# frozen_string_literal: true

module Alpaca
  module Broker
    # Incoming ACATS transfers from other brokerages.
    class ACATS < Resource
      # Lazily lists transfers. Filters: account_number, transfer_type, transfer_direction,
      # transfer_status, dtcc_status, contra_broker_number, since, until, sort_by,
      # sort_direction, limit.
      operation broker: "listACATSTransfers"
      def list(**params)
        paginate("/v1beta1/acats", model: AcatsTransfer, query: params, items_key: "transfers",
          token_key: "page_token_next")
      end

      operation broker: "listACATSTransfersByAccount"
      def list_for_account(account_id, **params)
        paginate(path("/v1beta1/acats", account_id), model: AcatsTransfer, query: params, items_key: "transfers",
          token_key: "page_token_next")
      end

      # Initiates an incoming transfer: contra_account_details:, transfer_details:,
      # ip_address:, signed_at:. Returns the new acats_id.
      operation broker: "requestACATSTransfer"
      def create(account_id, **params)
        data = http_post(path("/v1beta1/acats", account_id), body: params)
        data && data["acats_id"]
      end

      operation broker: "getACATSTransfer"
      def find(account_id, acats_id)
        http_get(path("/v1beta1/acats", account_id, acats_id), model: AcatsTransfer)
      end

      operation broker: "listACATSAssets"
      def assets(account_id, acats_id)
        http_get(path("/v1beta1/acats", account_id, acats_id, "assets"), model: AcatsAsset) || []
      end

      operation broker: "listACATSContraBrokers"
      def contra_brokers
        data = http_get("/v1beta1/acats/contrabrokers")
        AcatsContraBroker.build(data && data["brokers"]) || []
      end
    end

    # Portfolio rebalancing: model portfolios, account subscriptions and runs.
    class Rebalancing
      attr_reader :portfolios, :subscriptions, :runs

      def initialize(client)
        @portfolios = RebalancingPortfolios.new(client)
        @subscriptions = RebalancingSubscriptions.new(client)
        @runs = RebalancingRuns.new(client)
      end
    end

    class RebalancingPortfolios < Resource
      # Filters: name, description, symbol, portfolio_id, status.
      operation broker: "get-v1-rebalancing-portfolios"
      def list(**params)
        http_get("/v1/rebalancing/portfolios", query: params, model: RebalancingPortfolio) || []
      end

      operation broker: "get-v1-rebalancing-portfolios-portfolio_id"
      def find(portfolio_id)
        http_get(path("/v1/rebalancing/portfolios", portfolio_id), model: RebalancingPortfolio)
      end

      # name:, description:, weights: [{type: :asset, symbol:, percent:}], cooldown_days:, rebalance_conditions:
      operation broker: "post-v1-rebalancing-portfolios"
      def create(**params)
        http_post("/v1/rebalancing/portfolios", body: params, model: RebalancingPortfolio)
      end

      operation broker: "patch-v1-rebalancing-portfolios-portfolio_id"
      def update(portfolio_id, **params)
        http_patch(path("/v1/rebalancing/portfolios", portfolio_id), body: params, model: RebalancingPortfolio)
      end

      # Portfolios can't be deleted, only made inactive.
      operation broker: "delete-v1-rebalancing-portfolios-portfolio_id"
      def deactivate(portfolio_id)
        http_delete(path("/v1/rebalancing/portfolios", portfolio_id))
        true
      end
    end

    class RebalancingSubscriptions < Resource
      # Lazily lists subscriptions. Filters: account_id, portfolio_id, limit.
      operation broker: "get-v1-rebalancing-subscriptions"
      def list(**params)
        paginate("/v1/rebalancing/subscriptions", model: RebalancingSubscription, query: params,
          items_key: "subscriptions")
      end

      operation broker: "get-v1-rebalancing-subscriptions-subscription_id"
      def find(subscription_id)
        http_get(path("/v1/rebalancing/subscriptions", subscription_id), model: RebalancingSubscription)
      end

      operation broker: "post-v1-rebalancing-subscriptions"
      def create(account_id:, portfolio_id:)
        http_post("/v1/rebalancing/subscriptions", body: {account_id: account_id, portfolio_id: portfolio_id},
          model: RebalancingSubscription)
      end

      operation broker: "delete-v1-rebalancing-subscriptions-subscription_id"
      def delete(subscription_id)
        http_delete(path("/v1/rebalancing/subscriptions", subscription_id))
        true
      end
    end

    class RebalancingRuns < Resource
      # Lazily lists runs. Filters: account_id, status, type, limit.
      operation broker: "get-v1-rebalancing-runs"
      def list(**params)
        paginate("/v1/rebalancing/runs", model: RebalancingRun, query: params, items_key: "runs")
      end

      operation broker: "get-v1-rebalancing-runs-run_id"
      def find(run_id)
        http_get(path("/v1/rebalancing/runs", run_id), model: RebalancingRun)
      end

      # Manual run: type: (:full_rebalance or :invest_cash), amount:, weights:
      operation broker: "post-v1-rebalancing-runs"
      def create(account_id:, type:, **params)
        http_post("/v1/rebalancing/runs", body: {account_id: account_id, type: type, **params}, model: RebalancingRun)
      end

      operation broker: "delete-v1-rebalancing-runs-run_id"
      def cancel(run_id)
        http_delete(path("/v1/rebalancing/runs", run_id))
        true
      end
    end

    class IPOs < Resource
      # Lazily lists offerings. Filters: availability, ticker, limit.
      operation broker: "listIPOOfferings"
      def list(**params)
        paginate("/v1/ipos", model: IPOOffering, query: params, items_key: "data")
      end

      operation broker: "getIPOOffering"
      def find(offering_reference)
        data = http_get(path("/v1/ipos", offering_reference))
        IPOOffering.build(data && data["data"])
      end
    end

    # Fully Paid Securities Lending.
    class FPSL < Resource
      # Lazily lists loans. Filters: account_id, start, end, limit.
      operation broker: "get-v1-list-fpsl-loans"
      def loans(**params)
        paginate("/v1/fpsl/loans", model: FPSLLoan, query: params, items_key: "loans")
      end

      operation broker: "get-v1-list-fpsl-tiers"
      def tiers
        http_get("/v1/fpsl/tiers", model: FPSLTier) || []
      end

      # Loan analytics for one account (start:, end:). Returns the analytics Hash.
      operation broker: "get-v1-fpsl-analytics-account-loans"
      def analytics(account_id, **params)
        http_get(path("/v1/fpsl/analytics", account_id, "loans"), query: params)
      end
    end

    # End-of-day reporting.
    class Reporting < Resource
      # Firm-wide aggregate positions for a date. Filters: symbols, firm_accounts.
      operation broker: "get-v1-reporting-eod-aggregate_positions"
      def aggregate_positions(date:, **params)
        http_get("/v1/reporting/eod/aggregate_positions", query: {date: date, **params}, model: AggregatePosition) || []
      end

      # Lazily lists EOD positions, yielding Positions with an extra `account_id`.
      # Filters: account_id, asset, asof, limit.
      operation broker: "get-v1-reporting-eod-positions"
      def positions(**params)
        Collection.new do |cursor|
          response = connection.request(:get, "/v1/reporting/eod/positions",
            query: cursor ? params.merge(page_token: cursor) : params)
          data = response.data || {}
          items = (data["positions"] || {}).flat_map do |account_id, positions|
            Array(positions).map { |p| Position.new(p.merge("account_id" => account_id), response: response) }
          end
          token = data["next_page_token"]
          Collection::Page.new(items: items, next_cursor: token.to_s.empty? ? nil : token, response: response)
        end
      end

      # Lazily lists daily cash interest. Filters: account_id, date, after, before, direction, page_size.
      operation broker: "get-v1-get-eod-cash-interest-report"
      def cash_interest(**params)
        paginate("/v1/reporting/eod/cash_interest", model: DailyCashInterest, query: params, items_key: "interest")
      end
    end

    # Smaller reference endpoints.
    class ReferenceData < Resource
      operation broker: "get-v1-list-apr-tiers"
      def apr_tiers
        data = http_get("/v1/cash_interest/apr_tiers")
        APRTier.build(data && data["apr_tiers"]) || []
      end

      # Hash of ISO 3166 country code => CountryInfo.
      operation broker: "queryCountryInfos"
      def country_info
        (http_get("/v1/country-info") || {}).transform_values { |info| CountryInfo.build(info) }
      end

      # Signs an agreement for a party or account: agreement:, signed_at:, ip_address:, account_id:, ...
      operation broker: "createAgreement"
      def create_agreement(**params)
        http_post("/v1/agreements", body: params, model: Agreement)
      end

      # Raw logo image bytes. placeholder: false returns 404 instead of a placeholder image.
      operation broker: "get-v1beta1-logos-symbol"
      def logo(symbol, **params)
        download(path("/v1beta1/logos", symbol), query: params)
      end
    end

    # Alpaca Connect OAuth flows on behalf of your customers.
    class OAuth < Resource
      # response_type:, redirect_uri:, scope:
      operation broker: "getOAuthClient"
      def find_client(client_id, **params)
        http_get(path("/v1/oauth/clients", client_id), query: params, model: OAuthClient)
      end

      # Issues an authorization code for account_id (code flow).
      operation broker: "authorizeOAuthToken"
      def authorize(**params)
        http_post("/v1/oauth/authorize", body: params, model: OAuthAuthorization)
      end

      # Issues an access token directly for account_id.
      operation broker: "issueOAuthToken"
      def issue_token(**params)
        http_post("/v1/oauth/token", body: params, model: OAuthToken)
      end
    end
  end
end
