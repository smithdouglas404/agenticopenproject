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
module PerformanceData
  class ProjectsSeeder < Seeder
    TARGET_PROJECT_COUNT = 2_000
    MEMBERS_PER_PROJECT = 20

    # How many times the work packages configured via YAML are going to be seeded into each project
    WORK_PACKAGE_MULTIPLIER = 10

    def seed_data!
      print_status " ↳ Creating performance projects..."
      create_projects
    end

    def applicable?
      Project.count < TARGET_PROJECT_COUNT
    end

    def create_projects
      project_indexes.each do |index|
        ActiveRecord::Base.transaction do
          project = Project.new(project_data(index))

          project.save!

          seed_members(project)
          seed_versions(project)
          seed_work_packages(project)
        end
      end
    end

    def project_indexes
      (Project.count + 1)..TARGET_PROJECT_COUNT
    end

    def project_data(index)
      create_progress = index.to_f / TARGET_PROJECT_COUNT
      active_chance = create_progress < 0.5 ? 0 : 100 * (create_progress**2)

      {
        active: chance?(active_chance),
        name: "[perf] Project ##{index}",
        identifier: "mass-project-#{index}",
        enabled_module_names: project_modules,
        types: Type.all,
        workspace_type: Project.workspace_types[:project],
        work_package_custom_field_ids: custom_field_ids
      }
    end

    def seed_members(project)
      @user_ids ||= User.not_builtin.pluck(:id)

      admin_seeded = false
      @user_ids.sample(MEMBERS_PER_PROJECT).each do |id|
        role_name = if !admin_seeded || chance?(10)
                      admin_seeded = true
                      :default_role_project_admin
                    elsif chance?(70)
                      :default_role_member
                    else
                      :default_role_reader
                    end

        role = seed_data.find_reference(role_name)

        Member.create! project:, user_id: id, roles: [role]
      end
    end

    def seed_versions(project)
      version_data = seed_data.lookup("projects.scrum-project.versions")
      return unless version_data.is_a? Array

      version_data.each do |attributes|
        project.versions.create!(
          name: attributes["name"],
          status: attributes["status"],
          sharing: attributes["sharing"]
        )
      end
    end

    def seed_work_packages(project)
      seeder = DemoData::WorkPackageSeeder.new(project, seed_data.lookup("performance_projects"))
      WORK_PACKAGE_MULTIPLIER.times { seeder.seed! }
    end

    def custom_field_ids
      @custom_field_ids ||= CustomField.where("name like 'CF DEV%'").pluck(:id)
    end

    def project_modules
      Setting.default_projects_modules - %w(news wiki meetings calendar)
    end

    def chance?(percent)
      rand < percent / 100.0
    end
  end
end
