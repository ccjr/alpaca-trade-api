# frozen_string_literal: true

module Alpaca
  module Broker
    # Customer accounts: onboarding, updates, closure and options approval.
    class Accounts < Resource
      # Filters: query (name/email/account number search), created_after, created_before,
      # status, sort, entities (e.g. %w[contact identity]).
      operation broker: "getAllAccounts"
      def list(**params)
        http_get("/v1/accounts", query: params, model: BrokerAccount) || []
      end

      operation broker: "getAccount"
      def find(account_id)
        http_get(path("/v1/accounts", account_id), model: BrokerAccount)
      end

      # Opens an account: contact:, identity:, disclosures:, agreements:, documents:,
      # trusted_contact:, enabled_assets:, ... (see Alpaca's account creation docs).
      operation broker: "createAccount"
      def create(**params)
        http_post("/v1/accounts", body: params, model: BrokerAccount)
      end

      operation broker: "patchAccount"
      def update(account_id, **params)
        http_patch(path("/v1/accounts", account_id), body: params, model: BrokerAccount)
      end

      operation broker: "post-v1-accounts-account_id-actions-close"
      def close(account_id)
        http_post(path("/v1/accounts", account_id, "actions", "close"))
        true
      end

      # Requests options trading level 1-3 for an account (reviewed by Alpaca).
      operation broker: "requestOptionsForAccount"
      def request_options(account_id, level:)
        http_post(path("/v1/accounts", account_id, "options", "approval"), body: {level: level}, model: OptionsApproval)
      end

      # Lazily lists options approval requests. Filters: account_id, status,
      # requested_level, approved_level, page_size.
      operation broker: "requestListOptionsApprovals"
      def options_approvals(**params)
        paginate("/v1/accounts/options/approvals", model: OptionsApproval, query: params, items_key: "options_approvals")
      end

      # Bulk positions across all accounts, one page per `page` number.
      # Yields Positions with an extra `account_id` field.
      operation broker: "get-v1-accounts-positions"
      def all_positions(**params)
        Collection.new do |cursor|
          page = cursor || params.fetch(:page, 1)
          response = connection.request(:get, "/v1/accounts/positions", query: params.merge(page: page))
          items = positions_by_account(response.data && response.data["positions"], response)
          Collection::Page.new(items: items, next_cursor: items.empty? ? nil : page + 1, response: response)
        end
      end

      operation broker: "listIRAExcessContributions"
      def ira_excess_contributions
        http_get("/v1/accounts/ira_excess_contributions", model: IRAExcessContribution) || []
      end

      private

      def positions_by_account(map, response)
        (map || {}).flat_map do |account_id, positions|
          Array(positions).map { |position| Position.new(position.merge("account_id" => account_id), response: response) }
        end
      end
    end

    # Account documents (statements, confirms, tax forms) and owner document uploads.
    class Documents < Resource
      # Filters: start, end (dates), type (:account_statement, :trade_confirmation, :tax_statement, ...).
      operation broker: "getDocsForAccount"
      def list(account_id, **params)
        http_get(path("/v1/accounts", account_id, "documents"), query: params, model: AccountDocument) || []
      end

      # Returns the document bytes (PDF or JSON for trade_confirmation_json).
      operation broker: "downloadDocFromAccount"
      def download(account_id, document_id)
        download_path(path("/v1/accounts", account_id, "documents", document_id, "download"))
      end

      operation broker: "get-v1-accounts-account_id-documents-w8ben-document_id-download"
      def download_w8ben(account_id, document_id)
        download_path(path("/v1/accounts", account_id, "documents", "w8ben", document_id, "download"))
      end

      # Uploads owner documents: [{document_type:, document_sub_type:, content: base64, mime_type:}].
      # Pass `content_data: File.binread(path)` instead of `content:` to have it base64-encoded.
      operation broker: "uploadDocToAccount"
      def upload(account_id, documents)
        body = Array(documents).map { |doc| encode(doc) }
        http_post(path("/v1/accounts", account_id, "documents", "upload"), body: body)
        true
      end

      private

      # Resource#download is shadowed by the public #download above.
      def download_path(url)
        connection.request(:get, url, headers: {"Accept" => "*/*"}).body
      end

      def encode(doc)
        doc = doc.to_h { |key, value| [key.to_sym, value] }
        data = doc.delete(:content_data)
        data ? doc.merge(content: [data].pack("m0")) : doc
      end
    end

    # KYC: Customer Identification Program results and Onfido SDK flow.
    class KYC < Resource
      operation broker: "get-v1-accounts-account_id-cip"
      def cip(account_id)
        http_get(path("/v1/accounts", account_id, "cip"), model: CIPInfo)
      end

      # Submits CIP results from your own KYC provider: kyc:, document:, photo:, identity:, watchlist:.
      operation broker: "post-v1-accounts-account_id-cip"
      def submit_cip(account_id, **params)
        http_post(path("/v1/accounts", account_id, "cip"), body: params)
        true
      end

      # Token for initializing the Onfido SDK: referrer:, platform: (:web, :ios, :android).
      operation broker: "get-v1-accounts-account_id-onfido-sdk-tokens"
      def onfido_token(account_id, **params)
        data = http_get(path("/v1/accounts", account_id, "onfido", "sdk", "tokens"), query: params)
        data && data["token"]
      end

      # Reports the Onfido SDK outcome (:USER_EXITED, :USER_COMPLETED, ...).
      operation broker: "patch-v1-accounts-account_id-onfido-sdk"
      def update_onfido_outcome(account_id, token:, outcome:, reason: nil)
        http_patch(path("/v1/accounts", account_id, "onfido", "sdk"),
          body: {token: token, outcome: outcome, reason: reason})
        true
      end
    end

    # Account activities across all (or one) of your customer accounts.
    class Activities < Resource
      # Lazily lists activities, newest first. Filters: account_id, activity_types,
      # category, date, after, until, direction, page_size (default 100).
      operation broker: %w[getAccountActivities getAccountActivitiesByType]
      def list(activity_type = nil, **params)
        endpoint = activity_type ? path("/v1/accounts/activities", activity_type) : "/v1/accounts/activities"
        paginate_by_last_id(endpoint, model: Activity, query: params)
      end
    end
  end
end
