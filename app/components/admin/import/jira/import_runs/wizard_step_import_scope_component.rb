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

module Admin::Import::Jira::ImportRuns
  class WizardStepImportScopeComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers
    include Admin::Import::Jira::ImportRunsHelper

    def import_stats_available
      [
        projects_label(available_projects_count),
        issues_label(available_issues_count),
        statuses_label(available_statuses_count),
        types_label(available_types_count),
        I18n.t(:"admin.jira.run.wizard.sections.import_scope.elements.users")
      ].map { |label| { label:, checked: true } }
    end

    def import_stats_unavailable
      [
        I18n.t(:"admin.jira.run.wizard.sections.import_scope.elements.relations"),
        I18n.t(:"admin.jira.run.wizard.sections.import_scope.elements.workflows"),
        I18n.t(:"admin.jira.run.wizard.sections.import_scope.elements.permissions"),
        I18n.t(:"admin.jira.run.wizard.sections.import_scope.elements.sprints"),
        I18n.t(:"admin.jira.run.wizard.sections.import_scope.elements.schemes")
      ].map { |label| { label:, checked: false } }
    end

    def server_info
      info = model.available["server_info"]
      return "" unless info

      [
        info["serverTitle"],
        info["version"],
        "(#{info['baseUrl']})"
      ].join(" ")
    end

    def selected_projects_count
      model.projects&.count || 0
    end

    def available_projects_count
      model.available["projects"]&.count
    end

    def available_issues_count
      model.available["total_issues"]
    end

    def available_statuses_count
      model.available["total_statuses"]
    end

    def available_types_count
      model.available["total_issue_types"]
    end
  end
end
