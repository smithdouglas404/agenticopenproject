require 'spec_helper'

RSpec.describe Exports::PDF::Common::View do
  describe 'Arabic text shaping integration' do
    let(:view) { described_class.new(:en) }

    it 'applies Arabic shaping to text method' do
      pdf = view.document
      # text method should accept Arabic without error
      expect { pdf.text('مرحبا بالعالم') }.not_to raise_error
    end

    it 'applies Arabic shaping to formatted_text method' do
      pdf = view.document
      expect { pdf.formatted_text([{ text: 'مرحبا' }]) }.not_to raise_error
    end

    it 'applies Arabic shaping to make_cell method' do
      pdf = view.document
      expect { pdf.make_cell('مرحبا', {}) }.not_to raise_error
    end
  end
end
