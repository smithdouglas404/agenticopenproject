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

RSpec.describe OpenProject::AccessControl, "Backlogs module permissions" do # rubocop:disable RSpec/SpecFilePathFormat
  describe "view_sprints" do
    subject { described_class.permission(:view_sprints) }

    it "depends on view_work_packages and show_board_views" do
      expect(subject.dependencies).to contain_exactly(:view_work_packages, :show_board_views)
    end
  end

  describe "create_sprints" do
    subject { described_class.permission(:create_sprints) }

    it "depends on view_sprints" do
      expect(subject.dependencies).to contain_exactly(:view_sprints)
    end
  end

  describe "manage_sprint_items" do
    subject { described_class.permission(:manage_sprint_items) }

    it "depends on view_sprints, add_work_packages, and edit_work_packages" do
      expect(subject.dependencies).to contain_exactly(:view_sprints)
    end
  end

  describe "start_complete_sprint" do
    subject { described_class.permission(:start_complete_sprint) }

    it "depends on view_sprints and manage_board_views" do
      expect(subject.dependencies).to contain_exactly(:view_sprints, :manage_board_views, :manage_sprint_items)
    end

    it "covers both start and finish sprint actions" do
      expect(subject.controller_actions).to include("rb_sprints/start", "rb_sprints/finish")
    end

    context "when scrum_projects feature flag is active", with_flag: { scrum_projects: true } do
      it { is_expected.to be_visible }
    end

    context "when scrum_projects feature flag is inactive", with_flag: { scrum_projects: false } do
      it { is_expected.to be_hidden }
    end
  end

  describe "share_sprint" do
    subject { described_class.permission(:share_sprint) }

    it "depends on create_sprints" do
      expect(subject.dependencies).to contain_exactly(:create_sprints)
    end

    context "when scrum_projects feature flag is active", with_flag: { scrum_projects: true } do
      it { is_expected.to be_visible }
    end

    context "when scrum_projects feature flag is inactive", with_flag: { scrum_projects: false } do
      it { is_expected.to be_hidden }
    end
  end
end
