# frozen_string_literal: true

module Alpaca
  # A lazy, auto-paginating list. Pages are fetched only as iteration reaches
  # them, so `first(10)` costs one request and `each` streams with constant memory.
  # Each new iteration re-runs the query from the first page.
  class Collection
    include Enumerable

    Page = Data.define(:items, :next_cursor, :response) do
      def last? = next_cursor.nil?
    end

    # fetch: callable receiving the cursor (nil for the first page) and returning a Page.
    def initialize(&fetch)
      raise ArgumentError, "a page fetcher block is required" unless fetch

      @fetch = fetch
    end

    def each(&block)
      return enum_for(:each) unless block

      each_page { |page| page.items.each(&block) }
      self
    end

    def each_page
      return enum_for(:each_page) unless block_given?

      cursor = nil
      loop do
        page = @fetch.call(cursor)
        yield page
        break if page.last? || page.items.empty?

        cursor = page.next_cursor
      end
      self
    end

    def first_page = @fetch.call(nil)

    def inspect = "#<#{self.class.name} (lazy; call #to_a or #first(n))>"
  end
end
