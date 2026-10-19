# frozen_string_literal: true

module Alpaca
  module Trading
    # Server-Sent Events for the Trading API account.
    class Events < Resource
      # Account activities as they happen (fills, dividends, fees, ...).
      # since/until (times) or since_id/until_id (ULIDs) replay history first.
      operation trading: "subscribeToActivitiesSSE"
      def activities(**params)
        EventStream.new(connection, "/v2beta1/events/activities", query: params, model: ActivityEvent)
      end
    end
  end
end
