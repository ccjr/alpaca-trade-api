# frozen_string_literal: true

module Alpaca
  module Broker
    class ACHRelationships < Resource
      # statuses: e.g. %w[QUEUED APPROVED]
      operation broker: "getAccountACHRelationships"
      def list(account_id, **params)
        http_get(path("/v1/accounts", account_id, "ach_relationships"), query: params, model: ACHRelationship) || []
      end

      # account_owner_name:, bank_account_type: (:CHECKING/:SAVINGS), bank_account_number:,
      # bank_routing_number:, nickname:, or processor_token: (Plaid).
      operation broker: "createACHRelationshipForAccount"
      def create(account_id, **params)
        http_post(path("/v1/accounts", account_id, "ach_relationships"), body: params, model: ACHRelationship)
      end

      operation broker: "deleteACHRelationshipFromAccount"
      def delete(account_id, ach_relationship_id)
        http_delete(path("/v1/accounts", account_id, "ach_relationships", ach_relationship_id))
        true
      end
    end

    # Wire recipient banks.
    class RecipientBanks < Resource
      operation broker: "getRecipientBanks"
      def list(account_id, **params)
        http_get(path("/v1/accounts", account_id, "recipient_banks"), query: params, model: Bank) || []
      end

      operation broker: "createRecipientBank"
      def create(account_id, **params)
        http_post(path("/v1/accounts", account_id, "recipient_banks"), body: params, model: Bank)
      end

      operation broker: "deleteRecipientBank"
      def delete(account_id, bank_id)
        http_delete(path("/v1/accounts", account_id, "recipient_banks", bank_id))
        true
      end
    end

    # ACH and wire transfers in and out of customer accounts.
    class Transfers < Resource
      # Filters: direction (:INCOMING, :OUTGOING), limit, offset.
      operation broker: "getTransfersForAccount"
      def list(account_id, **params)
        paginate_by_offset(path("/v1/accounts", account_id, "transfers"), model: Transfer, query: params)
      end

      #   transfers.create(account_id, transfer_type: :ach, relationship_id: rel.id, amount: "500", direction: :INCOMING)
      operation broker: "createTransferForAccount"
      def create(account_id, transfer_type:, amount:, direction:, **params)
        body = {transfer_type: transfer_type, amount: amount, direction: direction, **params}
        http_post(path("/v1/accounts", account_id, "transfers"), body: body, model: Transfer)
      end

      operation broker: "deleteTransfer"
      def cancel(account_id, transfer_id)
        http_delete(path("/v1/accounts", account_id, "transfers", transfer_id))
        true
      end
    end

    # Journals move cash (JNLC) or securities (JNLS) between accounts.
    class Journals < Resource
      # Filters: after, before, status, entry_type, to_account, from_account, limit.
      operation broker: "getAllJournals"
      def list(**params)
        http_get("/v1/journals", query: params, model: Journal) || []
      end

      operation broker: "get-v1-journals-journal_id"
      def find(journal_id)
        http_get(path("/v1/journals", journal_id), model: Journal)
      end

      #   journals.create(entry_type: :JNLC, from_account: firm_id, to_account: id, amount: "50")
      operation broker: "createJournal"
      def create(entry_type:, from_account:, to_account:, idempotency_key: nil, **params)
        body = {entry_type: entry_type, from_account: from_account, to_account: to_account, **params}
        http_post("/v1/journals", body: body, idempotency_key: idempotency_key, model: Journal)
      end

      # One-to-many: entries: [{to_account:, amount:}, ...]. Returns one Journal per entry
      # (failed entries carry error_message).
      operation broker: "createBatchJournal"
      def batch(from_account:, entries:, entry_type: :JNLC, idempotency_key: nil, **params)
        body = {entry_type: entry_type, from_account: from_account, entries: entries, **params}
        http_post("/v1/journals/batch", body: body, idempotency_key: idempotency_key, model: Journal) || []
      end

      # Many-to-one: entries: [{from_account:, amount:}, ...].
      operation broker: "post-v1-journals-reverse_batch"
      def reverse_batch(to_account:, entries:, entry_type: :JNLC, **params)
        body = {entry_type: entry_type, to_account: to_account, entries: entries, **params}
        http_post("/v1/journals/reverse_batch", body: body, model: Journal) || []
      end

      operation broker: "deleteJournalById"
      def cancel(journal_id)
        http_delete(path("/v1/journals", journal_id))
        true
      end
    end

    # Instant funding: credit buying power before the deposit settles.
    class InstantFunding < Resource
      # Filters: status, system_date, deadline, before, sort_by, sort_order, limit, offset.
      operation broker: "get-v1-instant-funding-list"
      def list(**params)
        paginate_by_offset("/v1/instant_funding", model: Alpaca::InstantFunding, query: params)
      end

      operation broker: "get-v1-instant-funding-single"
      def find(instant_funding_id)
        http_get(path("/v1/instant_funding", instant_funding_id), model: Alpaca::InstantFunding)
      end

      operation broker: "post-v1-instant-funding"
      def create(account_no:, source_account_no:, amount:, idempotency_key: nil)
        body = {account_no: account_no, source_account_no: source_account_no, amount: amount}
        http_post("/v1/instant_funding", body: body, idempotency_key: idempotency_key, model: Alpaca::InstantFunding)
      end

      operation broker: "delete-v1-instant-funding-single"
      def cancel(instant_funding_id)
        http_delete(path("/v1/instant_funding", instant_funding_id))
        true
      end

      # Correspondent-level limits.
      operation broker: "get-v1-instant-funding-correspondent-limits"
      def limits
        http_get("/v1/instant_funding/limits", model: FundingLimit)
      end

      operation broker: "get-v1-instant-funding-account-limits"
      def account_limits(account_numbers)
        http_get("/v1/instant_funding/limits/accounts", query: {account_numbers: Array(account_numbers)},
          model: FundingLimit) || []
      end

      # report_type:, system_date:
      operation broker: "get-v1-instant-funding-reports"
      def reports(**params)
        http_get("/v1/instant_funding/reports", query: params, model: InstantFundingReport) || []
      end

      operation broker: "get-v1-instant-funding-settlements"
      def settlements(**params)
        data = http_get("/v1/instant_funding/settlements", query: params)
        Settlement.build(data && data["settlements"]) || []
      end

      operation broker: "get-v1-instant-funding-settlements-single"
      def settlement(settlement_id)
        http_get(path("/v1/instant_funding/settlements", settlement_id), model: Settlement)
      end

      # transfers: [{instant_transfer_id:, ...}], additional_info:
      operation broker: "post-v1-instant-funding-settlements"
      def create_settlement(transfers:, **params)
        http_post("/v1/instant_funding/settlements", body: {transfers: transfers, **params}, model: Settlement)
      end
    end

    # Just-in-time settlement: ledgers, limits, reports and settlements.
    class JIT < Resource
      operation broker: "get-v1-jit-settlements"
      def settlements(**params)
        data = http_get("/v1/jit/settlements", query: params)
        Settlement.build(data && data["settlements"]) || []
      end

      operation broker: "get-v1-jit-settlements-single"
      def settlement(settlement_id)
        http_get(path("/v1/jit/settlements", settlement_id), model: Settlement)
      end

      # accounts: [{account_number:, amount:}], asset_class:, currency:
      operation broker: "post-v1-jit-settlements"
      def create_settlement(accounts:, asset_class:, currency:, **params)
        body = {accounts: accounts, asset_class: asset_class, currency: currency, **params}
        http_post("/v1/jit/settlements", body: body, model: Settlement)
      end

      operation broker: "get-v1-transfers-jit-ledgers"
      def ledgers
        http_get("/v1/transfers/jit/ledgers", model: JITLedger) || []
      end

      # start_date:, end_date:
      operation broker: "get-v1-transfers-jit-ledger_id-balances"
      def ledger_balances(ledger_id, **params)
        http_get(path("/v1/transfers/jit", ledger_id, "balances"), query: params, model: JITLedger)
      end

      operation broker: "get-v1-transfers-jit-limits"
      def limits
        http_get("/v1/transfers/jit/limits", model: DailyTradingLimit)
      end

      # report_type: (:detail, :net_summary, ...), system_date:, asset_class:,
      # response_type: (:inline or :download_url). Returns the report Hash.
      operation broker: "get-v1-transfers-jit-reports"
      def reports(report_type:, system_date:, **params)
        http_get("/v1/transfers/jit/reports", query: {report_type: report_type, system_date: system_date, **params})
      end
    end

    # Global funding wallets (multi-currency deposits and withdrawals, beta).
    class FundingWallets < Resource
      operation broker: "getFundingWallet"
      def find(account_id)
        http_get(wallet(account_id), model: FundingWallet)
      end

      operation broker: "createFundingWallet"
      def create(account_id)
        http_post(wallet(account_id), model: FundingWallet)
      end

      operation broker: "batchCreateFundingWallets"
      def batch_create(account_ids)
        data = http_post("/v1beta/accounts/funding_wallet", body: {account_ids: Array(account_ids)})
        FundingWallet.build(data && data["funding_wallets"]) || []
      end

      # Deposit instructions. Filters: payment_type, currency.
      operation broker: "listFundingDetails"
      def funding_details(account_id, **params)
        http_get("#{wallet(account_id)}/funding_details", query: params)
      end

      operation broker: "getFundingWalletRecipientBank"
      def recipient_bank(account_id)
        http_get("#{wallet(account_id)}/recipient_bank", model: FundingWalletRecipientBank)
      end

      operation broker: "createFundingWalletRecipientBank"
      def create_recipient_bank(account_id, **params)
        http_post("#{wallet(account_id)}/recipient_bank", body: params, model: FundingWalletRecipientBank)
      end

      operation broker: "deleteFundingWalletRecipientBank"
      def delete_recipient_bank(account_id)
        http_delete("#{wallet(account_id)}/recipient_bank")
        true
      end

      operation broker: "getFundingWalletTransfers"
      def transfers(account_id)
        data = http_get("#{wallet(account_id)}/transfers")
        FundingWalletTransfer.build(data && data["transfers"]) || []
      end

      operation broker: "getFundingWalletTransferByID"
      def transfer(account_id, transfer_id)
        http_get(path("#{wallet(account_id)}/transfers", transfer_id), model: FundingWalletTransfer)
      end

      # usd_amount:, payment_type:, desired_currency:, fee_inclusive:
      operation broker: "createFundingWalletWithdrawal"
      def withdraw(account_id, **params)
        http_post("#{wallet(account_id)}/withdrawal", body: params, model: FundingWalletTransfer)
      end

      # Sandbox only: simulates an incoming bank deposit.
      operation broker: "demoDepositFunding"
      def demo_deposit(**params)
        http_post("/v1beta/demo/banking/funding", body: params, model: DemoFundingTransfer)
      end

      private

      def wallet(account_id) = path("/v1beta/accounts", account_id, "funding_wallet")
    end
  end
end
