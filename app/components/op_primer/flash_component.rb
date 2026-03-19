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
module OpPrimer
  class FlashComponent < Primer::Alpha::Banner
    include ApplicationHelper
    include OpTurbo::Streamable
    include OpPrimer::ComponentHelpers

    def initialize(flash_type: nil, **system_arguments)
      @unique_key = system_arguments.delete(:unique_key)
      @flash_type = flash_type&.to_sym

      system_arguments[:test_selector] ||= "op-primer-flash-message"
      system_arguments[:dismiss_scheme] ||= :remove
      system_arguments[:dismiss_label] ||= dismiss_label_for(@flash_type)
      system_arguments[:data] ||= {}
      system_arguments[:data]["flash-target"] = "flash"
      system_arguments[:data]["flash-type"] = @flash_type
      system_arguments[:data]["flash-role"] = aria_role
      system_arguments[:role] ||= aria_role

      @autohide = autohide?
      system_arguments[:data]["autohide"] = @autohide

      super
    end

    def render_as_turbo_stream(...)
      return unless render?

      super
    end

    private

    def render?
      trimmed_content.present?
    end

    def autohide?
      @flash_type.in?([:success, :notice])
    end

    def aria_role
      @flash_type.in?([:error, :danger]) ? "alert" : "status"
    end

    def dismiss_label_for(type)
      case type
      when :error, :danger
        I18n.t("js.dismiss_error_notification", default: "Dismiss error notification")
      else
        I18n.t("js.dismiss_notification", default: "Dismiss notification")
      end
    end
  end
end
