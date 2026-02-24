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

class Backlog
  extend ActiveModel::Naming

  attr_accessor :sprint, :stories, :project

  delegate :id, to: :sprint, prefix: true

  def self.for(sprint:, project:)
    owner_backlog = sprint.settings(project)&.display == VersionSetting::DISPLAY_RIGHT
    new(sprint:, stories: sprint.stories(project), owner_backlog:, project:)
  end

  def self.owner_backlogs(project)
    backlogs = Sprint.apply_to(project).with_status_open.displayed_right(project).order(:name)

    stories_by_sprints = Story.backlogs(project.id, backlogs.map(&:id))

    backlogs.map { |sprint| new(stories: stories_by_sprints[sprint.id], owner_backlog: true, sprint:, project:) }
  end

  def self.sprint_backlogs(project)
    sprints = Sprint.apply_to(project).with_status_open.displayed_left(project).order_by_date

    stories_by_sprints = Story.backlogs(project.id, sprints.map(&:id))

    sprints.map { |sprint| new(stories: stories_by_sprints[sprint.id], sprint:, project:) }
  end

  def initialize(sprint:, stories:, project:, owner_backlog: false)
    @sprint = sprint
    @stories = stories
    @project = project
    @owner_backlog = owner_backlog
  end

  def updated_at
    @stories.max_by(&:updated_at).try(:updated_at)
  end

  def owner_backlog?
    !!@owner_backlog
  end

  def sprint_backlog?
    !owner_backlog?
  end

  def to_key
    [sprint_id]
  end

  def edit_name_path
    url_helpers.edit_name_backlogs_project_sprint_path(project, sprint)
  end

  def add_work_package_path(type_id)
    url_helpers.new_project_work_packages_dialog_path(
      project,
      version_id: sprint.id,
      type_id:
    )
  end

  def view_stories_path
    url_helpers.backlogs_project_sprint_query_path(project, sprint)
  end

  private

  def url_helpers
    Rails.application.routes.url_helpers
  end
end
