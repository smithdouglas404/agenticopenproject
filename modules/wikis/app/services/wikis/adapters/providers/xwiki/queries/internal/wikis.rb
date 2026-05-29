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
          module Internal
            # Fetches the list of all wiki IDs from an XWiki farm.
            # Used as a preflight by other queries that need to iterate over all wikis.
            # Returns Success(["xwiki", "mywiki", ...])
            class Wikis < BaseQuery
              def call(http:)
                handle_response(http.with(headers: JSON_ACCEPT_HEADERS).get("#{base_rest_url}/wikis"))
              end

              private

              def handle_response(response)
                return failure(code: :connection_error) if response.is_a?(HTTPX::ErrorResponse)

                case response
                in { status: 200..299 }
                  handle_success_response(response)
                in { status: 401 | 403 }
                  failure(code: :unauthorized)
                else
                  failure(code: :request_failed)
                end
              end

              def handle_success_response(response)
                data = response.json
                wiki_ids = (data["wikis"] || []).filter_map { it["id"] }
                success(wiki_ids)
              rescue MultiJson::ParseError
                failure(code: :invalid_response)
              end
            end
          end
        end
      end
    end
  end
end
