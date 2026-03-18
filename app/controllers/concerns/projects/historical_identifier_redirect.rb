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

module Projects
  # Provides controller helpers for redirecting requests with historical (outdated)
  # project identifiers to URLs with the current identifier.
  #
  # When a project's identifier changes, friendly_id's :history extension records
  # the old identifier. This module checks if a request uses an old identifier and
  # issues a 301 redirect to the same URL with the current identifier.
  #
  # Usage in controllers:
  #
  #   class SomeController < ApplicationController
  #     before_action :find_project_by_project_id
  #     before_action :authorize
  #     redirect_historical_project_identifier param_key: :project_id
  #   end
  #
  # The redirect_historical_project_identifier declaration should:
  # - Come AFTER the finder that sets @project
  # - Come AFTER any authorization checks
  # - Use the same action scope (only/except) as the finder
  #
  # The redirect logic automatically:
  # - Only redirects GET requests (skips POST/PUT/PATCH/DELETE)
  # - Only redirects HTML format requests (skips turbo_stream, JSON, etc.)
  # - Only redirects when @project is present
  # - Only redirects when the param is a friendly_id slug (not numeric ID)
  # - Only redirects when the slug differs from current identifier
  module HistoricalIdentifierRedirect
    extend ActiveSupport::Concern

    included do
      # Declares a before_action to check and redirect historical project identifiers.
      #
      # @param param_key [Symbol] The parameter name containing the project identifier
      #   (default: :project_id, use :id for ProjectsController and similar)
      # @param options [Hash] Standard before_action options (only, except, if, unless, etc.)
      #
      # @example
      #   redirect_historical_project_identifier param_key: :project_id, only: %i[show edit]
      def self.redirect_historical_project_identifier(param_key: :project_id, **)
        before_action(**) do
          check_and_redirect_historical_project_identifier(param_key)
        end
      end
    end

    # Can be called directly from action methods if needed (for edge cases).
    # Typically you should use the redirect_historical_project_identifier class method instead.
    #
    # @param param_key [Symbol] The parameter name containing the project identifier
    def redirect_if_historical_project_identifier(param_key)
      check_and_redirect_historical_project_identifier(param_key)
    end

    private

    def check_and_redirect_historical_project_identifier(param_key)
      return unless should_redirect_historical_identifier?

      param_value = params[param_key]

      return unless param_value.friendly_id?
      return if param_value == @project.identifier

      redirect_to_current_identifier(param_key)
    end

    def should_redirect_historical_identifier?
      request.get? &&
        request.format.symbol == :html &&
        @project.present?
    end

    def redirect_to_current_identifier(param_key)
      safe_path_params = request.path_parameters.symbolize_keys
      safe_query_params = request.query_parameters.symbolize_keys

      # Replace the old identifier with the current one
      safe_path_params[param_key] = @project.identifier

      # Remove any URL option keys that could affect the redirect target (security)
      safe_query_params.except!(:host, :protocol, :subdomain, :domain, :port)

      redirect_to url_for(safe_path_params.merge(safe_query_params).merge(only_path: true)),
                  status: :moved_permanently
    end
  end
end
