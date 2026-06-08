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
module ::ResourceManagement
  class ResourceAllocationsController < BaseController
    include OpTurbo::ComponentStream

    menu_item :resource_management

    before_action :find_project_by_project_id
    before_action :authorize

    def new
      respond_with_dialog ResourceAllocations::NewDialogComponent.new(
        project: @project,
        work_package: context_work_package
      )
    end

    def step
      # Pre-select the autocompleter when the dialog was opened from a work package.
      render_allocation_step(ResourceAllocation.new(entity: context_work_package))
    end

    def edit; end

    def create
      # The confirmation step's "Back" button resubmits the carried form values
      # so the editable step can be re-rendered pre-filled.
      return render_allocation_step(set_attributes(create_params).result) if params[:back].present?

      validation = set_attributes(create_params)

      if validation.failure?
        return render_allocation_step(validation.result, status: :unprocessable_entity)
      end

      if validation.result.schedule_violation && params[:confirmed].blank?
        return render_outside_dates_step(validation.result)
      end

      persist_allocation
    end

    def update; end

    def destroy; end

    private

    def render_allocation_step(allocation, status: :ok)
      replace_via_turbo_stream(
        component: ResourceAllocations::AllocationStep::FormComponent.new(
          allocation:,
          project: @project,
          allocation_kind:
        ),
        status:
      )
      replace_via_turbo_stream(component: ResourceAllocations::AllocationStep::FooterComponent.new)
      respond_with_turbo_streams(status:)
    end

    def render_outside_dates_step(allocation)
      replace_via_turbo_stream(
        component: ResourceAllocations::OutsideDatesStep::FormComponent.new(
          allocation:,
          project: @project,
          allocation_kind:,
          form_values: submitted_allocation_params,
          filters: params[:filters]
        )
      )
      replace_via_turbo_stream(component: ResourceAllocations::OutsideDatesStep::FooterComponent.new)
      respond_with_turbo_streams
    end

    def persist_allocation
      call = ResourceAllocations::CreateService
               .new(user: current_user, model: ResourceAllocation.new)
               .call(create_params)

      if call.success?
        render_create_success
      else
        render_allocation_step(call.result, status: :unprocessable_entity)
      end
    end

    def set_attributes(attributes)
      ResourceAllocations::SetAttributesService
        .new(user: current_user, model: ResourceAllocation.new, contract_class: ResourceAllocations::CreateContract)
        .call(attributes)
    end

    def render_create_success
      render_success_flash_message_via_turbo_stream(
        message: I18n.t("resource_management.allocate_resource_dialog.success_message")
      )
      close_dialog_via_turbo_stream("##{ResourceAllocations::NewDialogComponent::DIALOG_ID}")
      respond_with_turbo_streams
    end

    def allocation_kind
      params[:allocation_kind].presence || "principal"
    end

    def filter_based_kind?
      allocation_kind == "filter"
    end

    def context_work_package
      return @context_work_package if defined?(@context_work_package)

      @context_work_package = resolve_entity("WorkPackage", params[:work_package_id])
    end

    # Raw, untransformed values to carry through the confirmation step as hidden
    # inputs so a confirmed resubmit recreates exactly what the user entered.
    def submitted_allocation_params
      params
        .fetch(:resource_allocation, {})
        .permit(:principal_id, :filter_name, :start_date, :end_date, :allocated_hours, :entity_type, :entity_id)
        .to_h
    end

    def create_params
      permitted = params
                    .expect(resource_allocation: %i[principal_id filter_name start_date end_date allocated_hours
                                                    entity_type entity_id])
                    .to_h
                    .symbolize_keys

      principal_id = permitted.delete(:principal_id)
      entity = resolve_entity(permitted.delete(:entity_type), permitted.delete(:entity_id))
      permitted.merge(entity:, **resource_params(principal_id))
    end

    # Allow-list the type before constantizing it. Returns nil for an unknown
    # type or unreachable id, letting the entity validations surface the error.
    def resolve_entity(entity_type, entity_id)
      return if entity_id.blank?
      return unless ResourceAllocation::ALLOWED_ENTITY_TYPES.include?(entity_type)

      entity_type.constantize.visible(current_user).where(project: @project).find_by(id: entity_id)
    end

    def resource_params(principal_id)
      if filter_based_kind?
        { principal_explicit: false, principal: nil, user_filter: parsed_user_filter }
      else
        { principal_explicit: true, principal: User.find_by(id: principal_id), filter_name: nil, user_filter: [] }
      end
    end

    # `user_filter` serializes UserQuery filter objects, so convert the
    # FilterForm's JSON payload into them.
    def parsed_user_filter
      return [] if params[:filters].blank?

      query = UserQuery.new
      ::Queries::ParamsParser.parse(filters: params[:filters])
                             .fetch(:filters, [])
                             .each { |f| query.where(f[:attribute], f[:operator], f[:values]) }
      query.filters
    end
  end
end
