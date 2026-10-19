# frozen_string_literal: true

module Alpaca
  module Trading
    class Activities < Resource
      # Lazily lists account activities, newest first, following pages.
      #
      #   activities.list(activity_types: %w[FILL DIV], after: Date.today - 7)
      #   activities.list("FILL", date: Date.today)   # one type, via /activities/{type}
      #
      # Filters: activity_types, category, order_id, date, after, until,
      # direction, page_size (default 100).
      operation trading: %w[getAccountActivities getAccountActivitiesByActivityType]
      def list(activity_type = nil, **params)
        endpoint = activity_type ? path("/v2/account/activities", activity_type) : "/v2/account/activities"
        paginate_by_last_id(endpoint, model: Activity, query: params)
      end
    end
  end
end
