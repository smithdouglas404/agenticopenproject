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
require_relative "../support/pages/backlogs"

RSpec.describe "Stories in backlog", :js,
               :selenium do
  let!(:project) do
    create(:project,
           types: [story, task, other_story],
           enabled_module_names: %w(work_package_tracking backlogs))
  end
  let!(:story) { create(:type_feature) }
  let!(:other_story) { create(:type) }
  let!(:task) { create(:type_task) }
  let!(:priority) { create(:default_priority) }
  let!(:default_status) { create(:status, is_default: true) }
  let!(:other_status) { create(:status) }
  let!(:workflows) do
    create(:workflow,
           old_status: default_status,
           new_status: other_status,
           role:,
           type_id: story.id)
  end
  let(:role) do
    create(:project_role,
           permissions: %i(view_master_backlog
                           add_work_packages
                           view_work_packages
                           edit_work_packages
                           manage_subtasks
                           assign_versions))
  end
  let!(:current_user) do
    create(:user,
           member_with_roles: { project => role })
  end
  let!(:sprint_story1) do
    create(:work_package,
           project:,
           type: story,
           status: default_status,
           version: sprint,
           position: 1,
           story_points: 10)
  end
  let!(:sprint_story1_task) do
    create(:work_package,
           project:,
           type: task,
           status: default_status,
           version: sprint)
  end
  let!(:sprint_story2_parent) do
    create(:work_package,
           project:,
           type: create(:type),
           status: default_status,
           version: sprint)
  end
  let!(:sprint_story2) do
    create(:work_package,
           project:,
           type: story,
           status: default_status,
           version: sprint,
           position: 2,
           story_points: 20)
  end
  let!(:backlog_story1) do
    create(:work_package,
           project:,
           type: story,
           status: default_status,
           version: backlog)
  end
  let!(:sprint) do
    create(:version,
           project:,
           start_date: Date.today - 10.days,
           effective_date: Date.today + 10.days,
           version_settings_attributes: [{ project:, display: VersionSetting::DISPLAY_LEFT }])
  end
  let!(:backlog) do
    create(:version,
           project:,
           version_settings_attributes: [{ project:, display: VersionSetting::DISPLAY_RIGHT }])
  end
  let!(:other_project) do
    create(:project).tap do |p|
      create(:member,
             principal: current_user,
             project: p,
             roles: [role])
    end
  end
  let!(:sprint_story_in_other_project) do
    create(:work_package,
           project: other_project,
           type: story,
           status: default_status,
           version: sprint,
           story_points: 10)
  end
  let(:backlogs_page) { Pages::Backlogs.new(project) }

  before do
    login_as current_user
    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
            .and_return("story_types" => [story.id.to_s, other_story.id.to_s],
                        "task_type" => task.id.to_s)
  end

  it "displays stories which are editable" do
    backlogs_page.visit!

    # All stories are visible in their sprint/backlog
    # but non stories are not displayed
    backlogs_page
      .expect_story_in_sprint(sprint_story1, sprint)

    backlogs_page
      .expect_story_in_sprint(sprint_story2, sprint)

    backlogs_page
      .expect_story_in_sprint(backlog_story1, backlog)

    backlogs_page
      .expect_story_not_in_sprint(sprint_story2_parent, sprint)

    backlogs_page
      .expect_story_not_in_sprint(sprint_story1_task, sprint)

    backlogs_page
      .expect_story_not_in_sprint(sprint_story_in_other_project, sprint)

    backlogs_page
      .expect_stories_in_order(sprint, sprint_story1, sprint_story2)

    # Velocity is calculated by summing up all story points in a sprint
    backlogs_page
      .expect_velocity(sprint, 30)
  end
end
