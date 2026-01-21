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

module Admin
  module JiraImports
    class WizardComponent < ApplicationComponent
      include ApplicationHelper
      include Turbo::FramesHelper
      include OpTurbo::Streamable
      include OpPrimer::ComponentHelpers

      def self.wrapper_key = :jira_imports_wizard

      def import_stats_available
        [
          { label: projects_label(available_projects_count), checked: true },
          { label: "#{issues_label(available_issues_count)} (name, title and description)", checked: true },
          { label: statuses_label(available_statuses_count), checked: true },
          { label: types_label(available_types_count), checked: true }
        ]
      end

      def selected_stats
        [
          { label: projects_label(selected_projects_count), checked: true }
        ]
      end

      def available_projects_count
        model.available['projects']&.count
      end

      def available_issues_count
        model.available['total_issues']
      end

      def available_statuses_count
        model.available['total_statuses']
      end

      def available_types_count
        model.available['total_issue_types']
      end

      def import_stats_unavailable
        [
          { label: I18n.t(:"admin.jiras.run.wizard.sections.import_scope.unavailable.relations"), checked: false },
          { label: I18n.t(:"admin.jiras.run.wizard.sections.import_scope.unavailable.workflows"), checked: false },
          { label: I18n.t(:"admin.jiras.run.wizard.sections.import_scope.unavailable.users"), checked: false },
          { label: I18n.t(:"admin.jiras.run.wizard.sections.import_scope.unavailable.permissions"), checked: false }
        ]
      end

      def projects_label(count)
        I18n.t(:"admin.jiras.run.wizard.parts.projects", count: count || 0)
      end

      def issues_label(count)
        I18n.t(:"admin.jiras.run.wizard.parts.issues", count: count || 0)
      end

      def statuses_label(count)
        I18n.t(:"admin.jiras.run.wizard.parts.statuses", count: count || 0)
      end

      def types_label(count)
        I18n.t(:"admin.jiras.run.wizard.parts.types", count: count || 0)
      end

      def import_selection
        [
          { label: projects_label(selected_projects_count), checked: true },
          { label: issues_label(selected_issues_count), checked: true },
          { label: statuses_label(selected_statuses_count), checked: true },
          { label: types_label(selected_types_count), checked: true }
        ]
      end

      def selected_projects_count
        model.projects&.count || 0
      end

      def selected_issues_count
        model.selected["issues_count"] || 0
      end

      def selected_types_count
        model.selected["issue_type_ids"]&.count || 0
      end

      def selected_statuses_count
        model.selected["status_ids"]&.count || 0
      end
    end
  end
end
