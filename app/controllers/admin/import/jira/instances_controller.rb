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

module Admin::Import::Jira
  class InstancesController < ApplicationController
    include OpTurbo::ComponentStream

    layout "admin"

    menu_item :jira_import

    before_action :require_admin
    before_action :set_jira, only: %i[show edit update destroy delete_token]

    def index
      @jira_instances = Jira.all
    end

    def show
      @jira_imports = JiraImport.where(jira_id: @jira.id).order(id: :desc)
    end

    def new
      @jira = Jira.new
    end

    def edit; end

    def create
      result = ::Jiras::CreateService.new(user: User.current).call(jira_params)
      handle_service_result(result, success_path: -> { admin_import_jira_path(result.result.id) }, failure_view: :new)
    end

    def update
      result = ::Jiras::UpdateService.new(user: User.current, model: @jira).call(jira_params)
      handle_service_result(result, success_path: -> { admin_import_jiras_path }, failure_view: :edit)
    end

    def destroy
      if JiraImport.exists?(jira_id: @jira.id)
        flash[:error] = t(:"admin.jira.errors.cannot_delete_with_imports")
      else
        @jira.destroy!
        flash[:notice] = t(:notice_successful_delete)
      end
      redirect_to action: :index
    end

    def delete_token
      @jira.update!(personal_access_token: nil)
      flash[:notice] = t(:"admin.jira.token_deleted")
      redirect_to edit_admin_import_jira_path(@jira), status: :see_other
    end

    def test
      token = params[:personal_access_token]
      if token.blank? && params[:id].present?
        token = Jira.find(params[:id]).personal_access_token
      end
      test_configuration(params[:url], token)
    rescue J::ConnectionError => e
      render_error_flash_message_via_turbo_stream(message: t(:"admin.jira.test.connection_error", message: e.message))
    rescue J::ParseError
      render_error_flash_message_via_turbo_stream(message: t(:"admin.jira.test.parse_error"))
    rescue J::ApiError => e
      render_error_flash_message_via_turbo_stream(message: t(:"admin.jira.test.api_error", status: e.status))
    rescue StandardError => e
      Rails.logger.error("Unexpected error testing Jira configuration: #{e.class} - #{e.message}")
      render_error_flash_message_via_turbo_stream(message: t(:"admin.jira.test.error"))
    ensure
      respond_with_turbo_streams
    end

    private

    def set_jira
      @jira = Jira.find(params[:id])
    end

    def jira_params
      permitted = params.expect(jira: %i[name url personal_access_token])
      if action_name == "update" && permitted[:personal_access_token].blank?
        permitted.delete(:personal_access_token)
      end
      permitted
    end

    def handle_service_result(result, success_path:, failure_view:)
      if result.failure?
        @jira = result.result
        stream_form_component { |format| format.html { render failure_view } }
      else
        flash[:notice] = t(action_name == "create" ? :notice_successful_create : :notice_successful_update)
        redirect_to success_path.call
      end
    end

    def stream_form_component(&)
      update_via_turbo_stream(component: Admin::Import::Jira::FormComponent.new(@jira))
      respond_with_turbo_streams(&)
    end

    def valid_url?(url)
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    end

    def test_configuration(url, personal_access_token)
      if url.blank? || personal_access_token.blank?
        render_error_flash_message_via_turbo_stream(message: t(:"admin.jira.test.missing_credentials"))
        return
      end

      unless valid_url?(url)
        render_error_flash_message_via_turbo_stream(message: t(:"admin.jira.test.invalid_url"))
        return
      end

      client = J.new(url:, personal_access_token:)
      response = client.server_info

      if response.is_a?(Hash)
        server = response["serverTitle"] || Jira.model_name
        version = response["version"] || "?"
        render_success_flash_message_via_turbo_stream(message: t(:"admin.jira.test.success", server:, version:))
      else
        render_error_flash_message_via_turbo_stream(message: t(:"admin.jira.test.failed"))
      end
    end
  end
end
