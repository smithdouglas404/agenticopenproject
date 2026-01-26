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
      before_action :find_jira_and_jira_import, only: %i[show continue remove select_projects select_projects_modal revert_modal]

      def show; end

      def new
        jira = Jira.find(params[:jira_id])
        jira_import = JiraImport.create!(author_id: current_user.id, jira_id: jira.id, status: JiraImport::INITIAL)
        redirect_to(admin_import_jira_run_path(jira_id: jira.id, id: jira_import.id))
      end

      def continue
        unless @jira_import.status_running?
          case params[:step]
          when "init"
            init
          when "fetch"
            fetch_instance_meta
          when "stats"
            fetch_projects_meta
          when "import"
            import
          when "configure"
            configure
          when "revert"
            revert
          end
        end

        render_wizard
      rescue StandardError => e
        respond_to do |format|
          format.turbo_stream do
            render_error_flash_message_via_turbo_stream(message: e.message)
            respond_with_turbo_streams(status: :unprocessable_entity)
          end
          format.html do
            flash[:error] = e.message
            render_wizard
          end
        end
      end

      def select_projects
        @jira_import.update!(projects: params[:projects])
        redirect_to(admin_import_jira_run_path(jira_id: @jira.id, id: @jira_import.id))
      end

      def select_projects_modal
        respond_with_dialog Admin::JiraImports::SelectProjectsModalComponent.new(jira_import: @jira_import)
      end

      def revert_modal
        respond_with_dialog Admin::JiraImports::RevertConfirmDialogComponent.new(jira_import: @jira_import)
      end

      def remove
        raise StandardError.new(I18n.t(:"admin.jira.run.remove_error")) if @jira_import.status_running?

        @jira_import.destroy!
        redirect_to(admin_import_jira_path(@jira))
      end

      private

      def init
        return unless @jira_import.status_between?(JiraImport::INITIAL, JiraImport::CONFIGURING)

        @jira_import.update!(status: JiraImport::INITIAL)
      end

      def fetch_instance_meta
        return unless @jira_import.status_between?(JiraImport::INITIAL, JiraImport::CONFIGURING)

        job = JiraInstanceMetaDataJob.perform_later(@jira_import.id)
        @jira_import.update!(status: JiraImport::INSTANCE_META_FETCHING, job_id: job.job_id)
      end

      def fetch_projects_meta
        return unless @jira_import.status?(JiraImport::CONFIGURING, JiraImport::PROJECTS_META_ERROR)

        job = JiraProjectsMetaDataJob.perform_later(@jira_import.id)
        @jira_import.update!(status: JiraImport::PROJECTS_META_FETCHING, job_id: job.job_id)
      end

      def import
        return unless @jira_import.status?(JiraImport::IMPORT_ERROR, JiraImport::PROJECTS_META_DONE)

        job = JiraFetchAndImportProjectsJob.perform_later(@jira_import.id)
        @jira_import.update!(status: JiraImport::IMPORTING, job_id: job.job_id)
      end

      def configure
        return unless @jira_import.status?(JiraImport::INSTANCE_META_DONE)

        @jira_import.update!(status: JiraImport::CONFIGURING)
      end

      def revert
        return unless @jira_import.status?(JiraImport::REVERT_ERROR, JiraImport::IMPORTED)

        job = JiraRevertJiraImportJob.perform_later(@jira_import.id)
        @jira_import.update!(status: JiraImport::REVERTING, job_id: job.job_id)
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
