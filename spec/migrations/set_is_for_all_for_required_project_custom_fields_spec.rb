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
require Rails.root.join("db/migrate/20251211160744_set_is_for_all_for_required_project_custom_fields")

RSpec.describe SetIsForAllForRequiredProjectCustomFields, type: :model do
  # Project custom fields to be migrated
  let!(:required_project_cf) { create(:project_custom_field, :integer, is_required: true) }
  let!(:optional_project_cf) { create(:project_custom_field, :integer, is_required: false) }

  # Regular custom fields, to be ignored by the migration
  let!(:required_custom_field) { create(:custom_field, :integer, is_required: true) }
  let!(:optional_custom_field) { create(:custom_field, :integer, is_required: false) }

  describe "up migration" do
    it "updates all project custom fields with is_required=true to is_for_all=true" do
      expect(required_project_cf.is_for_all).to be_falsey
      expect(optional_project_cf.is_for_all).to be_falsey

      ActiveRecord::Migration.suppress_messages { described_class.migrate(:up) }

      expect(required_project_cf.reload.is_for_all).to be_truthy
      expect(optional_project_cf.reload.is_for_all).to be_falsey
    end

    it "ignores regular custom fields" do
      expect(required_custom_field.is_for_all).to be_falsey
      expect(optional_custom_field.is_for_all).to be_falsey

      ActiveRecord::Migration.suppress_messages { described_class.migrate(:up) }

      expect(required_custom_field.reload.is_for_all).to be_falsey
      expect(optional_custom_field.reload.is_for_all).to be_falsey
    end
  end
end
