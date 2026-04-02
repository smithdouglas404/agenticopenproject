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

# Generic controller that is responsible for rendering turbo stream based
# flash messages.
#
# It is useful when you have a frontend action that should trigger a flash message
# when you do not have an otherwise responsible controller. E.g., when a "copy to
# clipboard" button is clicked.
class FlashesController < ApplicationController
  include OpTurbo::ComponentStream

  no_authorization_required! :clipboard_copied_notice

  def clipboard_copied_notice
    render_flash_message_via_turbo_stream(
      scheme: :success,
      message: I18n.t("js.clipboard.copied_successful")
    )

    respond_with_turbo_streams
  end
end
