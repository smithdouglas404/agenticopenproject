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

class InplaceEditFieldsController < ApplicationController
  include OpTurbo::ComponentStream

  before_action :find_model
  before_action :set_attribute
  no_authorization_required! :edit, :update, :reset, :dialog

  def edit
    replace_via_turbo_stream(
      component: component(enforce_edit_mode: true),
      status: :ok
    )

    respond_with_turbo_streams
  end

  def update
    handler = update_registry.fetch_handler(@model)

    if handler.present?
      success = handler.call(
        model: @model,
        params: permitted_params,
        user: current_user
      )
    else
      raise ArgumentError, "Missing update handler for #{@model}"
    end

    if success
      render_success_flash_message_via_turbo_stream(
        message: I18n.t(:notice_successful_update)
      )
    end

    replace_via_turbo_stream(
      component: component(enforce_edit_mode: !success),
      status: success ? :ok : :unprocessable_entity
    )

    respond_with_turbo_streams
  rescue ArgumentError
    head :not_found
  end

  def reset
    replace_via_turbo_stream(component:)
    respond_with_turbo_streams
  end

  def dialog
    respond_with_dialog(
      OpenProject::Common::InplaceEditFieldDialogComponent.new(
        model: @model,
        attribute: @attribute,
        system_arguments: system_arguments.to_h.symbolize_keys
      )
    )
  end

  private

  def find_model
    model_class = resolve_model_class(params[:model])
    @model = model_class.visible.find(params[:id])
  rescue ActiveRecord::RecordNotFound, ArgumentError
    head :not_found
  end

  def resolve_model_class(model_param)
    return nil if model_param.blank?

    model_class =
      update_registry.resolve_model_class(model_param)

    unless model_class &&
           model_class < ApplicationRecord &&
           model_class.respond_to?(:visible)
      raise ArgumentError, "Unsupported model for inplace edit"
    end

    model_class
  end

  def set_attribute
    @attribute = params[:attribute].to_sym
  end

  def permitted_params
    if custom_field_via_fields_for?
      transform_custom_field_values_params.merge(custom_comments_params)
    else
      params.expect(@model.model_name.param_key => [@attribute]).merge(custom_comments_params)
    end
  end

  def custom_field_via_fields_for?
    @attribute.to_s.start_with?("custom_field_") &&
      params[@model.model_name.param_key]&.key?(:custom_field_values)
  end

  def custom_comments_params
    return {} unless @attribute.to_s.start_with?("custom_field_")

    custom_field_id = @attribute.to_s.delete_prefix("custom_field_")
    raw_comment = params.dig(@model.model_name.param_key, :custom_comments, custom_field_id)

    return {} if raw_comment.nil?

    { custom_comments: { custom_field_id => raw_comment } }
  end

  def transform_custom_field_values_params
    model_key = @model.model_name.param_key
    custom_field_id = @attribute.to_s.delete_prefix("custom_field_")

    # Strong Parameters doesn't support dynamic keys in nested hashes
    # So we extract the value directly from the raw params
    raw_value = params.dig(model_key, :custom_field_values, custom_field_id)

    # Handle both single-select and multi-select
    processed_value = if raw_value.is_a?(Array)
                        # Remove empty strings from the hidden field
                        cleaned_values = raw_value.compact_blank
                        # For single-select, unwrap the array to get the single value
                        cleaned_values.size <= 1 ? cleaned_values.first : cleaned_values
                      else
                        raw_value
                      end

    { @attribute => processed_value }
  end

  def component(enforce_edit_mode: false)
    OpenProject::Common::InplaceEditFieldComponent.new(
      model: @model,
      attribute: @attribute,
      enforce_edit_mode:,
      update_registry:,
      **system_arguments.to_h.symbolize_keys
    )
  end

  def update_registry
    @update_registry ||= OpenProject::InplaceEdit::UpdateRegistry.default
  end

  def system_arguments
    arguments = params[:system_arguments_json].presence || params.to_unsafe_h
                                    .values
                                    .filter_map { |v| v["system_arguments_json"] }
                                    .first

    arguments.nil? ? {} : JSON.parse(arguments)
  end
end
