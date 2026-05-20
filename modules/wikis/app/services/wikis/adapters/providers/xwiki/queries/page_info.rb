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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Wikis
  module Adapters
    module Providers
      module XWiki
        module Queries
          class PageInfo < BaseQuery
            ACCEPT_HEADERS = { "Accept" => "application/json" }.freeze

            def call(input_data:, auth_strategy:)
              ref = PageReference.parse(input_data.identifier)
              return failure(code: :not_found) unless ref

              url = "#{provider.url.chomp('/')}/rest#{ref.rest_path}"
              Adapters::Authentication[auth_strategy].call do |http|
                handle_response(
                  http.with(headers: ACCEPT_HEADERS).get(url),
                  identifier: input_data.identifier
                )
              end
            end

            private

            def handle_response(response, identifier:)
              return failure(code: :connection_error) if response.is_a?(HTTPX::ErrorResponse)

              case response
              in { status: 200..299 }
                handle_success_response(response, identifier:)
              in { status: 401 | 403 }
                failure(code: :unauthorized)
              in { status: 404 }
                failure(code: :not_found)
              else
                failure(code: :request_failed)
              end
            end

            def handle_success_response(response, identifier:)
              data = response.json
              success(
                Results::PageInfo.new(
                  identifier:,
                  title: data["title"],
                  href: data["xwikiAbsoluteUrl"],
                  provider:
                )
              )
            rescue MultiJson::ParseError
              failure(code: :invalid_response)
            end
          end
        end
      end
    end
  end
end
