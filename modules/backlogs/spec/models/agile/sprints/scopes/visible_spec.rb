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

RSpec.describe Agile::Sprints::Scopes::Visible do
  shared_let(:project) { create(:project) }
  shared_let(:other_project) { create(:project) }
  shared_let(:sprint) { create(:agile_sprint, project:) }
  shared_let(:sprint_in_other_project) { create(:agile_sprint, project: other_project) }
  shared_let(:role) { create(:project_role, permissions: [:view_sprints]) }
  shared_let(:user_with_permission) do
    create(:user).tap do |u|
      create(:member, project:, user: u, roles: [role])
    end
  end
  shared_let(:user_with_permission_in_both) do
    create(:user).tap do |u|
      create(:member, project:, user: u, roles: [role])
      create(:member, project: other_project, user: u, roles: [role])
    end
  end
  shared_let(:user_without_permission) do
    create(:user).tap do |u|
      create(:member,
             project:,
             user: u,
             roles: [create(:project_role, permissions: [:view_work_packages])])
    end
  end
  shared_let(:user_without_membership) { create(:user) }

  subject { Agile::Sprint.visible(current_user) }

  context "for a user with view_sprints in one project" do
    current_user { user_with_permission }

    it "returns the sprint in that project" do
      expect(subject).to contain_exactly(sprint)
    end

    it "does not return sprints from projects the user has no permission in" do
      expect(subject).not_to include(sprint_in_other_project)
    end
  end

  context "for a user with view_sprints in both projects" do
    current_user { user_with_permission_in_both }

    it "returns sprints from both projects" do
      expect(subject).to contain_exactly(sprint, sprint_in_other_project)
    end
  end

  context "for a user with a different permission but not view_sprints" do
    current_user { user_without_permission }

    it "returns no sprints" do
      expect(subject).to be_empty
    end
  end

  context "for a user without any membership" do
    current_user { user_without_membership }

    it "returns no sprints" do
      expect(subject).to be_empty
    end
  end

  context "when called without a user argument" do
    current_user { user_with_permission }

    it "uses User.current" do
      expect(Agile::Sprint.visible).to contain_exactly(sprint)
    end
  end
end
