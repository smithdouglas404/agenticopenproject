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
  class DepartmentsController < ::ApplicationController
    include OpTurbo::ComponentStream
    include GroupsHelper

    layout :admin_or_frame_layout

    menu_item :departments

    # TODO: We will check for users permission here
    before_action :require_admin
    before_action :find_group,
                  only: %i[show edit new_user add_user update add_users remove_user create_memberships edit_membership
                           destroy_membership]

    def index
      @groups = Group.with_detail.organizational_units.visible.order(:lastname)
    end

    def new_user
      @child_groups = @group.children
      @ancestors = @group.ancestors(order: :asc)
    end

    def add_user # rubocop:disable Metrics/AbcSize
      result = ::Departments::AddUserService
        .new(@group, user: current_user)
        .call(
          user_id: params[:user_id],
          remove_from_previous_department: params[:remove_from_previous_department] == "true"
        )

      if result.success?
        redirect_to admin_department_path(@group), status: :see_other
      elsif result.result.is_a?(Group)
        respond_with_dialog(
          Admin::Departments::MoveUserDialogComponent.new(
            user: User.find(params[:user_id]),
            from_department: result.result,
            to_department: @group
          )
        )
      else
        flash[:error] = result.errors.full_messages.join("\n")
        redirect_to admin_department_path(@group), status: :see_other
      end
    end

    def new_department
      @group = Group.visible.with_detail.organizational_units.find(params[:parent_id]) if params[:parent_id].present?

      if @group
        @child_groups = @group.children
        @ancestors = @group.ancestors(order: :asc)
      else
        @child_groups = Group.with_detail.organizational_units.visible.where_detail(parent_id: nil).order(:lastname)
      end
    end

    def add_department
      # TODO: Implement
    end

    def edit_organization_name
      replace_via_turbo_stream(component: Admin::Departments::OrganizationNameFormComponent.new)
      respond_with_turbo_streams
    end

    def cancel_edit_organization_name
      replace_via_turbo_stream(component: Admin::Departments::OrganizationNameComponent.new)
      respond_with_turbo_streams
    end

    def update_organization_name
      ::Settings::UpdateService
        .new(user: current_user)
        .call(organization_name: params[:organization_name])

      replace_via_turbo_stream(component: Admin::Departments::OrganizationNameComponent.new)
      respond_with_turbo_streams
    end

    # old groups interface that we adapted for departments.

    def show
      @groups = Group.with_detail.organizational_units.visible.order(:lastname)
      render action: :index
    end

    def edit; end

    def update
      service_call = ::Groups::UpdateService
                     .new(user: current_user, model: @group)
                     .call(permitted_params.group)

      if service_call.success?
        flash[:notice] = I18n.t(:notice_successful_update)
        redirect_to edit_admin_department_path(@group), status: :see_other
      else
        render action: :edit, status: :unprocessable_entity
      end
    end

    def add_users
      service_call = ::Groups::UpdateService
                     .new(user: current_user, model: @group)
                     .call(add_user_ids: Array(params[:user_ids]))

      respond_users_altered(service_call)
    end

    def remove_user
      service_call = ::Groups::UpdateService
                     .new(user: current_user, model: @group)
                     .call(remove_user_ids: Array(params[:user_id]))

      respond_users_altered(service_call)
    end

    def create_memberships
      membership_params = permitted_params.group_membership[:membership]

      service_call = ::Members::CreateService
                     .new(user: current_user)
                     .call(membership_params.merge(principal: @group))

      respond_membership_altered(service_call)
    end

    def edit_membership
      membership_params = permitted_params.group_membership

      @membership = Member.find(membership_params[:membership_id])

      service_call = ::Members::UpdateService
                     .new(model: @membership, user: current_user)
                     .call(membership_params[:membership])

      respond_membership_altered(service_call)
    end

    def destroy_membership
      member = Member.find(params[:membership_id])
      ::Members::DeleteService
        .new(model: member, user: current_user)
        .call

      flash[:notice] = I18n.t(:notice_successful_delete)
      redirect_to edit_admin_department_path(@group, tab: redirected_to_tab(member)), status: :see_other
    end

    private

    def admin_or_frame_layout
      return "turbo_rails/frame" if turbo_frame_request?

      "admin"
    end

    def find_group
      @group = Group.visible.organizational_units.includes(:members, :users, :group_detail).find(params[:id])
    end

    def respond_membership_altered(service_call)
      if service_call.success?
        flash[:notice] = I18n.t(:notice_successful_update)
      else
        flash[:error] = service_call.errors.full_messages.join("\n")
      end

      redirect_to edit_admin_department_path(@group, tab: redirected_to_tab(service_call.result))
    end

    def redirected_to_tab(membership)
      if membership.project
        "memberships"
      else
        "global_roles"
      end
    end

    def respond_users_altered(service_call)
      if service_call.success?
        flash[:notice] = I18n.t(:notice_successful_update)
      else
        service_call.apply_flash_message!(flash)
      end

      redirect_to edit_admin_department_path(@group, tab: "users"), status: :see_other
    end
  end
end
