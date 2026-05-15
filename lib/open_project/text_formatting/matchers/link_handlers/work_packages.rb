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

module OpenProject::TextFormatting::Matchers
  module LinkHandlers
    class WorkPackages < Base
      ##
      # Match work package links.
      # Condition: Separator is #|##|###
      # Condition: Prefix is nil
      def applicable?
        %w(# ## ###).include?(matcher.sep) && matcher.prefix.nil?
      end

      #
      # Examples:
      #
      # #1234, ##1234, ###1234, #PROJ-1, ##PROJ-1, ###PROJ-1
      def call
        identifier = matcher.identifier

        # Reject canonical-shape violations on the numeric branch so `#0123`
        # stays literal instead of resolving to WP 123. The semantic branch is
        # already shape-validated by the matcher regex.
        return if identifier.match?(/\A\d+\z/) && identifier.to_i.to_s != identifier

        render_link(identifier, matcher)
      end

      def render_link(identifier, matcher)
        if ["##", "###"].include?(matcher.sep)
          render_work_package_macro(identifier, detailed: (matcher.sep === "###"))
        else
          render_work_package_link(identifier)
        end
      end

      private

      def render_work_package_macro(identifier, detailed: false)
        ApplicationController.helpers.content_tag "opce-macro-wp-quickinfo",
                                                  "",
                                                  data: { id: identifier, detailed: }
      end

      def render_work_package_link(identifier)
        link_to("##{identifier}",
                work_package_path_or_url(id: identifier, only_path: context[:only_path]),
                class: "issue work_package",
                data: {
                  hover_card_trigger_target: "trigger",
                  hover_card_url: hover_card_work_package_path(identifier)
                })
      end
    end
  end
end
