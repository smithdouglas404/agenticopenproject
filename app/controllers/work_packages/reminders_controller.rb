# frozen_string_literal: true

# -- copyright
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
# ++

class WorkPackages::RemindersController < ApplicationController
  include OpTurbo::ComponentStream
  include Redmine::I18n

  layout false

  before_action :find_work_package
  before_action :find_or_build_reminder, only: %i[modal_body create]
  before_action :find_reminder, only: %i[update destroy]

  before_action :authorize

  def modal_body
    render WorkPackages::Reminder::ModalBodyComponent.new(
      remindable: @work_package,
      reminder: @reminder,
      preset: params[:preset]
    )
  end

  def form_contract_check
    attribute, value, form_action = params.values_at(:name, :value, :form_action)
    if attribute.blank? || value.blank? || form_action.blank?
      return render json: { valid: false, message: I18n.t(:error_blank) },
                    status: :bad_request
    end

    contract_class = "Reminders::#{form_action.to_s.camelize}Contract".constantize
    attribute = attribute.to_sym

    set_attributes_service = Reminders::SetAttributesService.new(
      user: current_user,
      model: Reminder.new,
      contract_class:
    ).perform(remind_at: value)

    if set_attributes_service.errors.include?(attribute)
      render plain: set_attributes_service.errors.full_messages_for(attribute).to_sentence,
             status: :unprocessable_entity
    else
      head :ok
    end
  rescue NameError
    render plain: I18n.t(:error_invalid_form_action),
           status: :bad_request
  rescue StandardError => e
    Rails.logger.error { "Error during form contract check: #{e.message}" }
    render plain: I18n.t(:error_internal_server_error),
           status: :internal_server_error
  end

  def create
    service_result = Reminders::CreateService.new(user: current_user)
                                             .call(reminder_params)

    if service_result.success?
      message = I18n.t("work_package.reminders.create_success_message",
                       reminder_time: reminder_chosen_time(service_result.result)).html_safe
      respond_with_success_flash_message(message:)
    else
      respond_with_error_modal_component(service_result)
    end
  end

  def update
    service_result = Reminders::UpdateService.new(user: current_user,
                                                  model: @reminder)
                                             .call(reminder_params)

    if service_result.success?
      respond_with_success_flash_message(message: I18n.t("work_package.reminders.success_update_message"))
    else
      respond_with_error_modal_component(service_result)
    end
  end

  def destroy
    service_result = Reminders::DeleteService.new(user: current_user,
                                                  model: @reminder)
                                             .call

    if service_result.success?
      respond_with_success_flash_message(message: I18n.t("work_package.reminders.success_deletion_message"))
    else
      render_error_flash_message_via_turbo_stream(message: service_result.errors.full_messages)
      respond_with_turbo_streams(status: :unprocessable_entity)
    end
  end

  private

  def respond_with_success_flash_message(message:)
    render_success_flash_message_via_turbo_stream(message:)
    respond_with_turbo_streams
  end

  def respond_with_error_modal_component(service_result)
    replace_via_turbo_stream(
      component: WorkPackages::Reminder::ModalBodyComponent.new(
        remindable: @work_package,
        reminder: service_result.result,
        errors: service_result.errors,
        remind_at_date: reminder_params[:remind_at_date],
        remind_at_time: reminder_params[:remind_at_time]
      )
    )

    respond_with_turbo_streams(status: :unprocessable_entity)
  end

  def reminder_chosen_time(reminder)
    OpPrimer::RelativeTimeComponent.new(
      datetime: in_user_zone(reminder.remind_at),
      month: :long
    ).render_in(view_context)
  end

  def find_work_package
    @work_package = WorkPackage.visible.find(params[:work_package_id])
  end

  # We assume for now that there is only one reminder per work package
  def find_or_build_reminder
    @reminder = reminders.last || @work_package.reminders.build
  end

  def find_reminder
    @reminder = reminders.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error_flash_message_via_turbo_stream(message: I18n.t(:error_reminder_not_found))
    respond_with_turbo_streams(status: :not_found)
    false
  end

  def reminders
    @work_package.reminders.upcoming_and_visible_to(User.current)
  end

  def reminder_params
    params.expect(reminder: %i[remind_at_date remind_at_time note])
          .merge(remindable: @work_package, creator: User.current)
  end
end
