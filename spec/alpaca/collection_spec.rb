# frozen_string_literal: true

RSpec.describe Alpaca::Collection do
  let(:pages) { {nil => [[1, 2], "a"], "a" => [[3, 4], "b"], "b" => [[5], nil]} }
  let(:calls) { [] }
  let(:collection) do
    described_class.new do |cursor|
      calls << cursor
      items, next_cursor = pages.fetch(cursor)
      described_class::Page.new(items: items, next_cursor: next_cursor, response: nil)
    end
  end

  it "iterates every page lazily" do
    expect(collection.to_a).to eq([1, 2, 3, 4, 5])
    expect(calls).to eq([nil, "a", "b"])
  end

  it "stops fetching once enough items were consumed" do
    expect(collection.first(3)).to eq([1, 2, 3])
    expect(calls).to eq([nil, "a"])
  end

  it "exposes pages" do
    expect(collection.each_page.map(&:items)).to eq([[1, 2], [3, 4], [5]])
    expect(collection.first_page.items).to eq([1, 2])
    expect(collection.each_page.to_a.last).to be_last
  end

  it "stops on an empty page even with a cursor" do
    empty = described_class.new { |_| described_class::Page.new(items: [], next_cursor: "x", response: nil) }
    expect(empty.to_a).to eq([])
  end

  it "returns enumerators and itself" do
    expect(collection.each).to be_a(Enumerator)
    expect(collection.each { nil }).to equal(collection)
    expect(collection.each_page { nil }).to equal(collection)
    expect(collection.inspect).to include("lazy")
  end

  it "requires a fetcher" do
    expect { described_class.new }.to raise_error(ArgumentError)
  end
end
