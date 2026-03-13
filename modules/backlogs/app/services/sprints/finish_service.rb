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

class Sprints::FinishService < BaseServices::BaseCallable
  include Shared::ServiceContext

  attr_reader :user, :model

  def initialize(user:, model:)
    super()
    @user = user
    @model = model
  end

  def perform
    in_context(model, send_notifications: false) do
      finish_sprint
    end
  end

  private

  def finish_sprint
    return unsuccessful_finish_result unless model.active?

    model.completed!

    ServiceResult.success(result: model)
  rescue ActiveRecord::RecordInvalid
    unsuccessful_finish_result
  end

  def unsuccessful_finish_result
    ServiceResult.failure(result: model,
                          errors: model.errors,
                          message: unsuccessful_finish_message)
  end

  def unsuccessful_finish_message
    model.errors.full_messages.to_sentence if model.errors.any?
  end
end
