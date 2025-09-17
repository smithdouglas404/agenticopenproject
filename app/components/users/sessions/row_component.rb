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

module Users
  module Sessions
    class RowComponent < ::OpPrimer::BorderBoxRowComponent
      property :firstname, :lastname
      delegate :current_session, :current_token, to: :table

      def record
        model
      end

      def session?
        record.is_a?(::Sessions::UserSession)
      end

      def token?
        record.is_a?(::Token::AutoLogin)
      end

      def current?
        (session? && record.current?(current_session)) || (token? && record == current_token)
      end

      def browser
        return I18n.t("users.sessions.unknown_browser") unless session? || token?

        data = record.data.with_indifferent_access
        name = data[:browser] || I18n.t("users.sessions.unknown_browser")
        version = data[:browser_version]
        version ? "#{name} (Version #{version})" : name
      end

      def device
        return I18n.t("users.sessions.unknown_os") unless session? || token?

        record.data.with_indifferent_access[:platform] || I18n.t("users.sessions.unknown_os")
      end

      def expires_on
        if token?
          format_expires(token_expires_at)
        else
          I18n.t("users.sessions.unknown")
        end
      end

      def updated_at
        if current?
          I18n.t("users.sessions.current")
        elsif token?
          helpers.format_time(record.created_at)
        else
          record.respond_to?(:updated_at) ? helpers.format_time(record.updated_at) : "-"
        end
      end

      private

      def button_links
        [delete_button]
      end

      def delete_button
        return if session? && record.current?(current_session)
        return if token? && record == current_token

        render(
          Primer::Beta::IconButton.new(
            icon: :x,
            scheme: :invisible,
            tag: :a,
            href: url_for(revoke_path),
            "aria-label": I18n.t(:button_revoke),
            data: {
              method: :delete,
              confirm: I18n.t(:text_are_you_sure),
              disable_with: I18n.t(:label_loading)
            }
          )
        )
      end

      def revoke_path
        if token?
          { controller: "/my/auto_login_tokens", action: "destroy", id: record }
        else
          url_for(controller: "/my/sessions", action: "destroy", id: record)
        end
      end

      def token_expires_at
        if token?
          record.expires_on
        else
          (record.created_at + Setting.autologin.days)
        end
      end

      def format_expires(time)
        helpers.distance_of_time_in_words(Time.current, time)
      end
    end
  end
end
