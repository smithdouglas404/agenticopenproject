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
  class JirasController < ApplicationController
    include OpTurbo::ComponentStream

    layout "admin"

    menu_item :jira_import

    before_action :require_admin

    def index
      @jiras = Jira.all
    end

    def show
      @jira = Jira.find(params[:id])
      @jira_imports = JiraImport.where(jira_id: @jira.id).sort_by(&:id)
    end

    def new
      @jira = Jira.new
    end

    def edit
      @jira = Jira.find(params[:id])
    end

    def create
      result = ::Jiras::CreateService.new(user: User.current).call(jira_params)
      result.on_failure do
        @jira = result.result
        stream_form_component do |format|
          format.html { render :new }
        end
      end

      result.on_success do
        flash[:notice] = t(:notice_successful_create)
        redirect_to(admin_import_jira_path(result.result.id))
      end
    end

    def update
      @jira = Jira.find(params[:id])
      result = ::Jiras::UpdateService.new(user: User.current, model: @jira).call(jira_params)

      result.on_failure do
        stream_form_component do |format|
          format.html { render :edit }
        end
      end

      result.on_success do
        flash[:notice] = t(:notice_successful_update)
        redirect_to action: :index
      end
    end

    def destroy; end

    private

    def jira_params
      params.expect(jira: %i[name url personal_access_token])
    end

    def stream_form_component(&)
      update_via_turbo_stream(component: Admin::Jiras::FormComponent.new(@jira))
      respond_with_turbo_streams(&)
    end
  end
end
