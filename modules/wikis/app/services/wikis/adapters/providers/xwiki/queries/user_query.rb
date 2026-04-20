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

            def initialize(wiki_provider)
              @wiki_provider = wiki_provider
            end

            def call(access_token:)
              response = get_userinfo(access_token)
              return Failure("XWiki userinfo request failed (#{response.code})") unless response.is_a?(Net::HTTPSuccess)

              body = JSON.parse(response.body)
              return Failure("XWiki userinfo response missing sub claim") if body["sub"].blank?

              Success(body["sub"])
            rescue StandardError => e
              Failure(e.message)
            end

            private

            def get_userinfo(access_token)
              uri = URI.parse("#{@wiki_provider.url.chomp('/')}/oidc/userinfo")
              http = Net::HTTP.new(uri.host, uri.port)
              http.use_ssl = uri.scheme == "https"

              request = Net::HTTP::Get.new(uri.request_uri)
              request["Authorization"] = "Bearer #{access_token}"
              request["Accept"] = "application/json"

              http.request(request)
            end
          end
        end
      end
    end
  end
end
