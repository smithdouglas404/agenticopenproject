# frozen_string_literal: true

# -- copyright
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
# ++

require "spec_helper"

RSpec.describe CustomFields::Scopes::Visible do
  shared_let(:project_cf) { create(:string_project_custom_field) }
  shared_let(:work_package_cf) { create(:string_wp_custom_field) }
  shared_let(:user_cf) { create(:user_custom_field) }
  shared_let(:group_cf) { create(:group_custom_field) }
  shared_let(:version_cf) { create(:version_custom_field) }
  shared_let(:time_entry_cf) { create(:time_entry_custom_field) }

  let(:project_cf_visible) { false }
  let(:work_package_cf_visible) { false }
  let(:user_cf_visible) { false }
  let(:group_cf_visible) { false }
  let(:version_cf_visible) { false }
  let(:time_entry_cf_visible) { false }

  # Since there would be very many tests here, we break the rule of testing
  # the scope as a black box. Knowing that the scope relies on the individual visible scopes of each
  # custom field class, we test them by selectively enabling/disabling the scopes of each.
  describe ".visible" do
    subject { CustomField.visible(current_user) }

    current_user { build_stubbed(:user) }

    before do
      {
        ProjectCustomField => project_cf_visible,
        WorkPackageCustomField => work_package_cf_visible,
        UserCustomField => user_cf_visible,
        GroupCustomField => group_cf_visible,
        VersionCustomField => version_cf_visible,
        TimeEntryCustomField => time_entry_cf_visible
      }.each do |klass, visible|
        allow(klass)
          .to receive(:visible)
                .with(current_user)
                .and_return(visible ? klass.all : klass.none)
      end
    end

    context "for a project custom field" do
      context "if the fields are visible" do
        let(:project_cf_visible) { true }

        it "returns the project custom field" do
          expect(subject).to contain_exactly(project_cf)
        end
      end

      context "if the fields are invisible" do
        let(:project_cf_visible) { false }

        it "does not return the project custom field" do
          expect(subject).to be_empty
        end
      end
    end

    context "for a work package custom field" do
      context "if the fields are visible" do
        let(:work_package_cf_visible) { true }

        it "returns the work package custom field" do
          expect(subject).to contain_exactly(work_package_cf)
        end
      end

      context "if the fields are invisible" do
        let(:work_package_cf_visible) { false }

        it "does not return the work package custom field" do
          expect(subject).to be_empty
        end
      end
    end

    context "for a user custom field" do
      context "if the fields are visible" do
        let(:user_cf_visible) { true }

        it "returns the user custom field" do
          expect(subject).to contain_exactly(user_cf)
        end
      end

      context "if the fields are invisible" do
        let(:user_cf_visible) { false }

        it "does not return the user custom field" do
          expect(subject).to be_empty
        end
      end
    end

    context "for a group custom field" do
      context "if the fields are visible" do
        let(:group_cf_visible) { true }

        it "returns the group custom field" do
          expect(subject).to contain_exactly(group_cf)
        end
      end

      context "if the fields are invisible" do
        let(:group_cf_visible) { false }

        it "does not return the group custom field" do
          expect(subject).to be_empty
        end
      end
    end

    context "for a version custom field" do
      context "if the fields are visible" do
        let(:version_cf_visible) { true }

        it "returns the version custom field" do
          expect(subject).to contain_exactly(version_cf)
        end
      end

      context "if the fields are invisible" do
        let(:version_cf_visible) { false }

        it "does not return the version custom field" do
          expect(subject).to be_empty
        end
      end
    end

    context "for a time_entry custom field" do
      context "if the fields are visible" do
        let(:time_entry_cf_visible) { true }

        it "returns the time_entry custom field" do
          expect(subject).to contain_exactly(time_entry_cf)
        end
      end

      context "if the fields are invisible" do
        let(:time_entry_cf_visible) { false }

        it "does not return the time_entry custom field" do
          expect(subject).to be_empty
        end
      end
    end
  end
end
