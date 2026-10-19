# frozen_string_literal: true

RSpec.describe Alpaca::Model do
  let(:leg_class) do
    Class.new(described_class) do
      attribute :qty, :decimal
    end
  end

  let(:model_class) do
    leg = leg_class
    Class.new(described_class) do
      attribute :id, :string
      attribute :qty, :decimal
      attribute :count, :integer
      attribute :active, :boolean
      attribute :submitted_at, :time
      attribute :expires_on, :date
      attribute :side, :symbol
      attribute :prices, [:decimal]
      attribute :legs, [leg]
      attribute :leg, leg
      attribute :class, :symbol
      attribute :method, :string
    end
  end

  subject(:model) do
    model_class.new(
      "id" => "abc", "qty" => "1.50", "count" => "7", "active" => "true",
      "submitted_at" => "2024-03-11T13:35:35.13312256Z", "expires_on" => "2024-12-20",
      "side" => "buy", "prices" => ["1.1", 2], "legs" => [{"qty" => "2"}], "leg" => {"qty" => 3},
      "class" => "us_equity", "method" => "ach", "brand_new_field" => {"x" => 1}
    )
  end

  it "coerces declared attributes" do
    expect(model.id).to eq("abc")
    expect(model.qty).to eq(BigDecimal("1.5"))
    expect(model.count).to eq(7)
    expect(model.active).to be(true)
    expect(model.active?).to be(true)
    expect(model.submitted_at).to eq(Time.utc(2024, 3, 11, 13, 35, 35, Rational(13_312_256, 100)))
    expect(model.expires_on).to eq(Date.new(2024, 12, 20))
    expect(model.side).to eq(:buy)
    expect(model.prices).to eq([BigDecimal("1.1"), BigDecimal(2)])
    expect(model.legs.first).to be_a(leg_class)
    expect(model.legs.first.qty).to eq(2)
    expect(model.leg.qty).to eq(3)
  end

  it "keeps undeclared fields reachable" do
    expect(model.brand_new_field).to eq({"x" => 1})
    expect(model[:brand_new_field]).to eq({"x" => 1})
    expect(model).to respond_to(:brand_new_field)
    expect(model).not_to respond_to(:missing_field)
    expect { model.missing_field }.to raise_error(NoMethodError)
  end

  it "never shadows core Ruby methods" do
    expect(model.class).to eq(model_class)
    expect(model["class"]).to eq(:us_equity)
    expect(model.method(:id)).to be_a(Method)
    expect(model["method"]).to eq("ach")
  end

  it "treats nil and empty strings as nil" do
    m = model_class.new("qty" => "", "submitted_at" => nil, "side" => "", "expires_on" => "")
    expect([m.qty, m.submitted_at, m.side, m.expires_on]).to all(be_nil)
  end

  it "converts Float and Integer to BigDecimal" do
    expect(model_class.new("qty" => 0.1).qty).to eq(BigDecimal("0.1"))
    expect(model_class.new("qty" => 4).qty).to eq(BigDecimal(4))
    expect(model_class.new("qty" => BigDecimal("9.9")).qty).to eq(BigDecimal("9.9"))
  end

  it "parses non-ISO times" do
    expect(model_class.new("submitted_at" => "Mon, 11 Mar 2024 13:35:35 GMT").submitted_at).to eq(Time.utc(2024, 3, 11, 13, 35, 35))
    now = Time.now
    expect(model_class.new("submitted_at" => now).submitted_at).to equal(now)
  end

  it "converts to a deep hash with symbol keys" do
    hash = model.to_h
    expect(hash[:qty]).to eq(BigDecimal("1.5"))
    expect(hash[:legs]).to eq([{qty: BigDecimal(2)}])
    expect(hash[:leg]).to eq({qty: BigDecimal(3)})
    expect(hash[:brand_new_field]).to eq({x: 1})
  end

  it "supports pattern matching" do
    result = case model
    in {side: :buy, qty:} then qty
    end
    expect(result).to eq(BigDecimal("1.5"))
    expect(model.deconstruct_keys(nil)).to eq(model.to_h)
  end

  it "is frozen, comparable and inspectable" do
    expect(model).to be_frozen
    copy = model_class.new(model.keys.to_h { |k| [k, model[k]] })
    expect(copy).to eq(model)
    expect(copy.hash).to eq(model.hash)
    expect(model).not_to eq(leg_class.new)
    expect(model.inspect).to include("qty=0.15e1")
    expect(model.key?(:qty)).to be(true)
  end

  it "builds arrays, nil and existing instances" do
    expect(model_class.build(nil)).to be_nil
    expect(model_class.build([{"id" => "1"}, {"id" => "2"}]).map(&:id)).to eq(%w[1 2])
    expect(model_class.build(model)).to equal(model)
  end

  it "inherits attributes from a parent model" do
    child = Class.new(model_class) { attribute :extra, :integer }
    instance = child.new("qty" => "2", "extra" => "5")
    expect(instance.qty).to eq(2)
    expect(instance.extra).to eq(5)
  end

  it "rejects unknown attribute types" do
    expect { Class.new(described_class) { attribute :x, :nope } }.to raise_error(ArgumentError)
    expect { Class.new(described_class) { attribute :x, [:nope] } }.to raise_error(ArgumentError)
  end
end
