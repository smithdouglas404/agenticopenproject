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
  module Jiras
    class JiraImportsController < ApplicationController
      include OpTurbo::ComponentStream

      layout "admin"

      menu_item :jira_import

      before_action :require_admin
      before_action :find_jira_and_jira_import, only: %i[show continue remove select_projects select_projects_modal]

      def show
      end

      def new
        jira = Jira.find(params[:jira_id])
        jira_import = JiraImport.create!(author_id: current_user.id, jira_id: jira.id, status: JiraImport::STATE_INITIAL)
        redirect_to(admin_jira_jira_import_path(jira_id: jira.id, id: jira_import.id))
      end

      def continue
        case params[:step]
        when "fetch"
          fetch
        when "import"
          import
        when "configure"
          configure
        end
        render_wizard
      end

      def select_projects
        @jira_import.update!(projects: params[:projects])
        redirect_to(admin_jira_jira_import_path(jira_id: @jira.id, id: @jira_import.id))
      end

      def select_projects_modal
        respond_with_dialog Admin::JiraImports::SelectProjectsModalComponent.new(jira_import: @jira_import)
      end

      def remove
        raise StandardError.new(I18n.t(:"admin.jiras.run.remove_error")) if @jira_import.status_running?

        @jira_import.destroy!
        redirect_to(admin_jira_path(@jira))
      end

      private

      def fetch
        return unless [JiraImport::STATE_FETCH_ERROR, JiraImport::STATE_INITIAL].include?(@jira_import.status)

        job = JiraMetaDataJob.perform_later(@jira_import.id)
        @jira_import.update!(status: JiraImport::STATE_FETCHING, job_id: job.job_id)
      end

      def import
        return unless [JiraImport::STATE_IMPORT_ERROR, JiraImport::STATE_CONFIGURING].include?(@jira_import.status)

        # job = JiraImportDataJob.perform_later(@jira_import.id)
        @jira_import.update!(status: JiraImport::STATE_IMPORTING)
      end

      def configure
        return unless @jira_import.status == JiraImport::STATE_FETCHED

        @jira_import.update!(status: JiraImport::STATE_CONFIGURING)
      end

      def revert
        return unless [JiraImport::STATE_REVERT_ERROR, JiraImport::STATE_IMPORTED].include?(@jira_import.status)

        @jira_import.update!(status: JiraImport::STATE_REVERTING)
      end

      def render_wizard
        render Admin::JiraImports::WizardComponent.new(@jira_import), layout: false
      end

      def find_jira_and_jira_import
        @jira = Jira.find(params[:jira_id])
        @jira_import = JiraImport.find(params[:id])
      end
    end
  end
end
