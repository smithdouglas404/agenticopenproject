# frozen_string_literal: true

require "spec_helper"

RSpec.describe "PDF RTL support" do
  describe "RTL locale detection" do
    let(:exporter_class) do
      Class.new do
        include Exports::PDF::Common::Common
        include Redmine::I18n
        public :rtl?, :align_start, :align_end
      end
    end

    let(:exporter) { exporter_class.new }

    context "with Arabic locale" do
      before { allow(exporter).to receive(:current_language).and_return(:ar) }

      it "detects RTL" do
        expect(exporter.rtl?).to be true
      end

      it "returns right for align_start" do
        expect(exporter.align_start).to eq(:right)
      end

      it "returns left for align_end" do
        expect(exporter.align_end).to eq(:left)
      end
    end

    context "with English locale" do
      before { allow(exporter).to receive(:current_language).and_return(:en) }

      it "does not detect RTL" do
        expect(exporter.rtl?).to be false
      end

      it "returns left for align_start" do
        expect(exporter.align_start).to eq(:left)
      end
    end
  end
end
