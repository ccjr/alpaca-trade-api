# frozen_string_literal: true

RSpec.describe Alpaca::Market::Client do
  describe '#crypto_bars' do
    it 'returns an array of Bar objects', :vcr do
      bars = subject.crypto_bars('SOLUSD', '1Min')
      expect(bars).to be_an(Array)
      expect(bars.first).to be_an(Alpaca::Market::Crypto::Bar)
    end
  end
end