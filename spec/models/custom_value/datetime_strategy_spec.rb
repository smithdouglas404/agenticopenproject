# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"

RSpec.describe CustomValue::DatetimeStrategy do
  let(:instance) { described_class.new(custom_value) }
  let(:custom_value) { instance_double(CustomValue, value:) }

  describe "#typed_value" do
    subject { instance.typed_value }

    context "when value is a UTC datetime string" do
      let(:value) { "2015-01-03T12:00:00Z" }

      it { is_expected.to eql(DateTime.iso8601(value)) }
    end

    context "when value is a datetime string with offset" do
      let(:value) { "2015-01-03T14:00:00+02:00" }

      it { is_expected.to eql(DateTime.iso8601(value)) }
    end

    context "when value is not a datetime" do
      let(:value) { "hello, world!" }

      it { is_expected.to be_nil }
    end

    context "when value is blank" do
      let(:value) { "" }

      it { is_expected.to be_nil }
    end

    context "when value is nil" do
      let(:value) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe "#formatted_value" do
    subject { instance.formatted_value }

    context "when value is a valid datetime string", with_settings: { time_format: "%Y-%m-%d %H:%M" } do
      let(:value) { "2015-01-03T00:00:00Z" }

      it "returns a formatted string" do
        expect(subject).to be_a(String)
        expect(subject).not_to be_empty
      end
    end

    context "when value is blank" do
      let(:value) { "" }

      it { is_expected.to be_nil }
    end

    context "when value is nil" do
      let(:value) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe "#validate_type_of_value" do
    subject { instance.validate_type_of_value }

    context "when value is valid UTC datetime string" do
      let(:value) { "2015-01-03T12:00:00Z" }

      it "accepts" do
        expect(subject).to be_nil
      end
    end

    context "when value is valid datetime string with offset" do
      let(:value) { "2015-01-03T14:00:00+02:00" }

      it "accepts" do
        expect(subject).to be_nil
      end
    end

    context "when value is a nonsense string" do
      let(:value) { "chicken" }

      it "rejects" do
        expect(subject).to be(:not_a_datetime)
      end
    end

    context "when value is a Time object" do
      let(:value) { Time.now }

      it "accepts" do
        expect(subject).to be_nil
      end
    end

    context "when value is a DateTime object" do
      let(:value) { DateTime.now }

      it "accepts" do
        expect(subject).to be_nil
      end
    end
  end
end
