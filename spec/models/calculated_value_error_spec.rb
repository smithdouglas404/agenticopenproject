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

RSpec.describe CalculatedValueError do
  shared_let(:project) { create(:project) }
  shared_let(:custom_field) { create(:custom_field) }
  shared_let(:other_custom_field) { create(:custom_field) }

  describe "validations" do
    it "validates project_id is present" do
      expect(subject).to validate_presence_of(:project_id)
    end

    it "validates custom_field_id is present" do
      expect(subject).to validate_presence_of(:custom_field_id)
    end

    it "validates uniqueness of project_id scoped to custom_field_id and error_code" do
      subject.project = project
      subject.custom_field = custom_field
      subject.error_code = "ERROR_MATHEMATICAL"
      expect(subject).to validate_uniqueness_of(:project_id).scoped_to(%i[custom_field_id error_code])
    end

    it "validates the error_code is one of the allowed values" do
      expect(subject).to validate_inclusion_of(:error_code).in_array(described_class::VALID_ERROR_CODES)
    end
  end

  describe "#error_message" do
    it "returns a human readable error message for the error code" do
      subject.error_code = "ERROR_MATHEMATICAL"
      expect(subject.error_message).to eq(I18n.t("calculated_values.errors.mathematical"))
    end

    it "returns a default message for unknown error codes" do
      subject.error_code = "UNKNOWN_ERROR_CODE"
      expect(subject.error_message).to eq(I18n.t("calculated_values.errors.unknown"))
    end

    describe "missing values" do
      it "includes the custom field name for a missing value" do
        subject.missing_custom_field_ids = [custom_field.id]

        subject.error_code = "ERROR_MISSING_VALUE"
        expect(subject.error_message).to eq(I18n.t("calculated_values.errors.missing_value",
                                                   custom_field_name: custom_field.name))
      end

      it "when there are multiple missing values, only includes the first custom field name" do
        subject.missing_custom_field_ids = [other_custom_field.id, custom_field.id]

        subject.error_code = "ERROR_MISSING_VALUE"
        expect(subject.error_message).to eq(I18n.t("calculated_values.errors.missing_value",
                                                   custom_field_name: other_custom_field.name))
      end
    end

    describe "disabled values" do
      it "includes the custom field name for a disabled value" do
        subject.missing_custom_field_ids = [custom_field.id]

        subject.error_code = "ERROR_DISABLED_VALUE"
        expect(subject.error_message).to eq(I18n.t("calculated_values.errors.disabled_value",
                                                   custom_field_name: custom_field.name))
      end

      it "when there are multiple disabled values, only includes the first custom field name" do
        subject.missing_custom_field_ids = [other_custom_field.id, custom_field.id]

        subject.error_code = "ERROR_DISABLED_VALUE"
        expect(subject.error_message).to eq(I18n.t("calculated_values.errors.disabled_value",
                                                   custom_field_name: other_custom_field.name))
      end
    end
  end
end
