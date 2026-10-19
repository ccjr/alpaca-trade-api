# frozen_string_literal: true

module Alpaca
  module Broker
    # Server-Sent Events for every account under the correspondent. Each method
    # returns a lazy EventStream: pass since/until (or since_id/until_id ULIDs)
    # to replay history; unbounded streams reconnect and resume automatically.
    #
    #   broker.events.trades(since: Time.now - 3600).each { |event| puts event.order.status }
    class Events < Resource
      operation broker: "subscribeToTradeV2SSE"
      def trades(**params) = stream("/v2/events/trades", params, TradeEvent)

      operation broker: "subscribeToActivitiesSSE"
      def activities(**params) = stream("/v2beta1/events/activities", params, ActivityEvent)

      # One activity event by its ULID.
      operation broker: "getAccountActivityEvent"
      def activity(account_id, event_id)
        EventStream.new(connection, path("/v2beta1/accounts", account_id, "events", "activities", event_id),
          model: ActivityEvent, reconnect: false).first
      end

      operation broker: "subscribeToJournalStatusV2SSE"
      def journals(**params) = stream("/v2/events/journals/status", params, JournalEvent)

      operation broker: "subscribeToFundingStatusSSE"
      def funding(**params) = stream("/v2/events/funding/status", params, FundingEvent)

      operation broker: "subscribeToAdminActionSSE"
      def admin_actions(**params) = stream("/v2/events/admin-actions", params, Event)

      operation broker: "subscribeToIPOEventsSSE"
      def ipos(**params) = stream("/v2/events/ipos", params, Event)

      operation broker: "subscribeToSystemEventV2SSE"
      def system(**params) = stream("/v2/events/system", params, Event)

      # Legacy (/v1) streams page by integer ids; the gem resumes with since_ulid.
      operation broker: "subscribeToAccountStatusSSE"
      def account_status(**params) = legacy("/v1/events/accounts/status", params, AccountStatusEvent)

      operation broker: "subscribeToJournalStatusSSE"
      def legacy_journals(**params) = legacy("/v1/events/journals/status", params, JournalEvent)

      operation broker: "subscribeToTransferStatusSSE"
      def transfers(**params) = legacy("/v1/events/transfers/status", params, TransferEvent)

      operation broker: "get-v1-events-nta"
      def non_trade_activities(**params) = legacy("/v1/events/nta", params, NonTradeActivityEvent)

      private

      def stream(endpoint, params, model)
        EventStream.new(connection, endpoint, query: params, model: model)
      end

      def legacy(endpoint, params, model)
        EventStream.new(connection, endpoint, query: params, model: model, resume: :since_ulid)
      end
    end
  end
end
