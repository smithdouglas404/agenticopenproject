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
  no_authorization_required! :edit, :update, :reset

  def edit
    replace_via_turbo_stream(
      component: component(enforce_edit_mode: true),
      status: :ok
    )

    respond_with_turbo_streams
  end

  def update
    handler = OpenProject::InplaceEdit::UpdateRegistry.fetch_handler(@model)

    success = handler.call(
      model: @model,
      params: permitted_params,
      user: current_user
    )

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
  end

  def reset
    replace_via_turbo_stream(component:)
    respond_with_turbo_streams
  end

  private

  def find_model
    model_class = resolve_model_class(params[:model])
    @model = model_class.visible
                        .find(params[:id])
  rescue NameError, ActiveRecord::RecordNotFound, ArgumentError, NoMethodError
    head :not_found
  end

  def resolve_model_class(model_param)
    return nil if model_param.blank?

    class_name = model_param.to_s.camelize
    # Only allow models that are registered for inplace updates.
    unless OpenProject::InplaceEdit::UpdateRegistry.registered?(class_name)
      raise ArgumentError, "Unsupported model for inplace edit"
    end

    model_class = class_name.safe_constantize

    # Guard against resolving arbitrary non-ActiveRecord constants.
    unless model_class.is_a?(Class) &&
           defined?(ApplicationRecord) &&
           model_class < ApplicationRecord &&
           model_class.respond_to?(:visible)
      raise ArgumentError, "Model is not an ActiveRecord model"
    end

    model_class
  end

  def set_attribute
    @attribute = params[:attribute].to_sym
  end

  def permitted_params
    params
      .expect(@model.model_name.param_key => [@attribute])
  end

  def component(enforce_edit_mode: false)
    OpenProject::Common::InplaceEditFieldComponent.new(
      model: @model,
      attribute: @attribute,
      enforce_edit_mode:,
      **system_arguments.to_h.symbolize_keys
    )
  end

  def system_arguments
    arguments = params[:system_arguments_json].presence || params.to_unsafe_h
                                    .values
                                    .filter_map { |v| v["system_arguments_json"] }
                                    .first

    arguments.nil? ? {} : JSON.parse(arguments)
  end
end
