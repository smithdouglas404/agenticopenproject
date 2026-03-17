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

module API
  module Helpers
    module HistoricalIdentifierRedirect
      # Redirects API requests using a historical project identifier to the canonical URL
      # with the project's current identifier.
      #
      # Returns a 301 Moved Permanently response when the request uses a historical
      # (retired) project identifier. This ensures API responses always use canonical URLs.
      #
      # @param identifier_param [Symbol] The route parameter name (e.g., :id, :project, :of)
      # @param project [Project] The loaded project instance
      #
      # @example In a Grape API endpoint
      #   route_param :id do
      #     after_validation do
      #       helpers ::API::Helpers::HistoricalIdentifierRedirect
      #       @project = Project.find(params[:id])
      #       redirect_if_historical_identifier(:id, @project)
      #     end
      #   end
      def redirect_if_historical_identifier(identifier_param, project)
        param_value = params[identifier_param]
        return unless request.get? && param_value.friendly_id? && param_value != project.identifier

        redirect canonical_identifier_path(identifier_param, param_value, project), permanent: true
      end

      def canonical_identifier_path(identifier_param, param_value, project)
        # Replace the old identifier in the path.
        # This prevents Host header injection and open redirect attacks.
        new_path = request.path.sub(
          %r{(/)#{Regexp.escape(param_value)}(/|-|$)},
          "\\1#{project.identifier}\\2"
        )

        # Replace the old identifier in query parameters if present
        if request.query_string.present?
          new_query_string = request.query_string.gsub(
            /(\A|&)#{Regexp.escape(identifier_param.to_s)}=#{Regexp.escape(param_value)}(&|\z)/,
            "\\1#{identifier_param}=#{CGI.escape(project.identifier)}\\2"
          )
          new_path += "?#{new_query_string}"
        end

        new_path
      end
    end
  end
end
