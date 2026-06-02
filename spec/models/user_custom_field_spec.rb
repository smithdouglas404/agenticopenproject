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

RSpec.describe UserCustomField do
  describe "validations" do
    it "is invalid without a section" do
      cf = build(:user_custom_field, custom_field_section_id: nil)
      expect(cf).not_to be_valid
      expect(cf.errors[:custom_field_section_id]).to be_present
    end

    it "is valid with a section" do
      expect(create(:user_custom_field)).to be_valid
    end
  end

  describe "associations" do
    it "belongs to a UserCustomFieldSection" do
      section = create(:user_custom_field_section)
      cf = create(:user_custom_field, user_custom_field_section: section)
      expect(cf.user_custom_field_section).to eq(section)
    end
  end

  describe "#type_name" do
    it "returns :label_user_plural" do
      expect(described_class.new.type_name).to eq(:label_user_plural)
    end
  end

  describe "defaults" do
    it "defaults visible_on_user_card to false" do
      cf = create(:user_custom_field)
      expect(cf.visible_on_user_card).to be(false)
    end
  end

  describe "acts_as_list within a section" do
    let(:section) { create(:user_custom_field_section) }
    let!(:cf_first) { create(:user_custom_field, user_custom_field_section: section, position_in_custom_field_section: 1) }
    let!(:cf_second) { create(:user_custom_field, user_custom_field_section: section, position_in_custom_field_section: 2) }

    it "orders fields by position within the section" do
      expect(section.custom_fields.to_a).to eq([cf_first, cf_second])
    end

    it "keeps positions scoped per section" do
      other_section = create(:user_custom_field_section)
      cf_other = create(:user_custom_field, user_custom_field_section: other_section)
      expect(cf_other.position_in_custom_field_section).to eq(1)
    end
  end

  describe ".visible" do
    let!(:admin_only_cf) { create(:user_custom_field, admin_only: true) }
    let!(:public_cf) { create(:user_custom_field, admin_only: false) }

    context "for an admin" do
      it "returns all custom fields" do
        expect(described_class.visible(build(:admin))).to include(admin_only_cf, public_cf)
      end
    end

    context "for a non-admin" do
      it "returns only non-admin_only custom fields" do
        expect(described_class.visible(build(:user))).to include(public_cf)
        expect(described_class.visible(build(:user))).not_to include(admin_only_cf)
      end
    end
  end

  describe "section cascade deletion" do
    it "is destroyed when its section is destroyed" do
      section = create(:user_custom_field_section)
      cf = create(:user_custom_field, user_custom_field_section: section)
      expect { section.destroy }.to change { described_class.exists?(cf.id) }.from(true).to(false)
    end
  end
end
