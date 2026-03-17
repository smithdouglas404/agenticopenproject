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
      # Issues a 301 redirect to the canonical URL when the request uses a historical
      # project identifier. The canonical URL is provided by the caller via a block,
      # which is only evaluated when a redirect is actually needed.
      #
      # @param param_value [String] The identifier value from the request params
      # @param project [Project] The loaded project instance
      # @yieldreturn [String] The canonical URL to redirect to
      #
      # @example
      #   redirect_if_historical_project_identifier(params[:id], @project) do
      #     api_v3_paths.project(@project.identifier)
      #   end
      def redirect_if_historical_project_identifier(param_value, project)
        if request.get? && param_value.friendly_id? && param_value != project.identifier
          redirect yield, permanent: true
        end
      end
    end
  end
end
