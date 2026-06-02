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
          class ReferencingPages < BaseQuery
            def call(input_data:, auth_strategy:)
              Adapters::Authentication[auth_strategy].call do |http|
                Internal::Wikis.new(model: provider).call(http:).bind do |wiki_names|
                  wiki_names.reduce(Success([])) do |acc, wiki_name|
                    acc.bind do |results|
                      search_wiki(wiki_name:, linkable: input_data.linkable,
                                  number: input_data.number, http:, auth_strategy:)
                        .fmap { results + it }
                    end
                  end
                end
              end
            end

            private

            def search_wiki(wiki_name:, linkable:, number:, http:, auth_strategy:)
              url = "#{base_rest_url}/wikis/#{wiki_name}/openproject/links/workPackages/#{linkable.id}"
              response = http.with(headers: JSON_ACCEPT_HEADERS).get(url, params: { number: })
              handle_response(response) { parse_search_results(response, auth_strategy:) }
            end

            def handle_response(response)
              return failure(code: :connection_error) if response.is_a?(HTTPX::ErrorResponse)

              case response
              in { status: 200..299 } then yield
              in { status: 401 | 403 } then failure(code: :unauthorized)
              in { status: 404 } then failure(code: :not_found)
              else failure(code: :request_failed)
              end
            end

            def parse_search_results(response, auth_strategy:)
              results = response.json["searchResults"] || []
              success(results.map { page_info(identifier: it["id"], auth_strategy:) })
            rescue MultiJson::ParseError
              failure(code: :invalid_response)
            end
          end
        end
      end
    end
  end
end
