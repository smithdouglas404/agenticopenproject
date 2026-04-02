require 'spec_helper'

RSpec.describe Exports::PDF::Common::ArabicShaping do
  describe '.contains_arabic?' do
    it 'returns true for Arabic text' do
      expect(described_class.contains_arabic?('مرحبا')).to be true
    end

    it 'returns false for Latin text' do
      expect(described_class.contains_arabic?('Hello')).to be false
    end

    it 'returns true for mixed text' do
      expect(described_class.contains_arabic?('Hello مرحبا')).to be true
    end
  end

  describe '.shape' do
    it 'converts Arabic to presentation forms' do
      shaped = described_class.shape('مرحبا')
      shaped.codepoints.each do |cp|
        expect(cp >= 0xFE70 && cp <= 0xFEFF || cp >= 0xFB50 && cp <= 0xFDFF).to be true
      end
    end

    it 'creates Lam-Alef ligatures' do
      shaped = described_class.shape('لا')
      expect(shaped.codepoints).to eq([0xFEFB])
    end

    it 'preserves diacritical marks' do
      shaped = described_class.shape("بِسْمِ")
      marks = shaped.codepoints.select { |cp| (0x064B..0x065F).cover?(cp) }
      expect(marks).not_to be_empty
    end

    it 'passes through non-Arabic text' do
      expect(described_class.shape('Hello')).to eq('Hello')
    end

    it 'handles nil and empty' do
      expect(described_class.process(nil)).to be_nil
      expect(described_class.process('')).to eq('')
    end

    it 'preserves spaces in mixed text' do
      shaped = described_class.shape('مرحبا بالعالم')
      expect(shaped).to include(' ')
    end
  end

  describe '.process' do
    it 'shapes and reorders Arabic text' do
      result = described_class.process('مرحبا')
      expect(result).not_to eq('مرحبا')
      expect(described_class.contains_arabic?(result)).to be true
    end
  end
end
