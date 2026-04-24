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
          class UserQuery
            include Dry::Monads[:result]

            def self.call(wiki_provider:, access_token:)
              new(model: wiki_provider).call(access_token:)
            end

            def initialize(model:)
              @wiki_provider = model
            end

            def call(access_token:)
              url = "#{@wiki_provider.url.chomp('/')}/rest/"

              handle_response(OpenProject.httpx.bearer_auth(access_token).get(url))
            end

            private

            def handle_response(response)
              return Failure(response.error.message) if response.is_a?(HTTPX::ErrorResponse)

              case response
              in { status: 200..299 }
                handle_success_response(response)
              else
                Failure("XWiki REST API request failed (#{response.status})")
              end
            end

            def handle_success_response(response)
              xwiki_user = response.headers["xwiki-user"]
              xwiki_user.present? ? Success(xwiki_user) : Failure("XWiki REST API response missing xwiki-user header")
            end
          end
        end
      end
    end
  end
end
