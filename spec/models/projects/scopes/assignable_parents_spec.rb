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

RSpec.describe Projects::Scopes::AssignableParents do
  shared_let(:add_subprojects_role) { create(:project_role, permissions: %i[add_subprojects]) }
  shared_let(:view_role) { create(:project_role, permissions: %i[]) }
  shared_let(:user) { create(:user) }
  shared_let(:project_with_permission) { create(:project, members: { user => add_subprojects_role }) }
  shared_let(:parent_project) { create(:project, members: { user => add_subprojects_role }) }
  shared_let(:subject_project, reload: true) do
    create(:project, parent: parent_project, members: { user => add_subprojects_role })
  end
  shared_let(:child_project) { create(:project, parent: subject_project, members: { user => add_subprojects_role }) }
  shared_let(:project_without_permission) { create(:project, members: { user => view_role }) }

  context "for a project" do
    it "returns all projects the user has the add_subprojects permission in but without self or descendants" do
      expect(Project.assignable_parents(user, subject_project))
        .to contain_exactly(project_with_permission, parent_project)
    end
  end

  context "for a portfolio" do
    before do
      subject_project.portfolio!
    end

    it "is empty" do
      expect(Project.assignable_parents(user, subject_project))
        .to be_empty
    end
  end

  context "for a program" do
    before do
      subject_project.program!
    end

    it "is empty" do
      expect(Project.assignable_parents(user, subject_project))
        .to be_empty
    end
  end
end
