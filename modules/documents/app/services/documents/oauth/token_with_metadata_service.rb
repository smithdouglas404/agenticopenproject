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

module Documents
  module OAuth
    class TokenWithMetadataService < BaseServices::BaseCallable
      include API::V3::Utilities::PathHelper

      def initialize(user:, document:, project:)
        super()

        @user = user
        @document = document
        @project = project
      end

      def perform
        token_result = GenerateTokenService.new(user: @user).call
        return token_result unless token_result.success?

        access_token = token_result.result

        payload = {
          resource_url:,
          oauth_token: access_token.plaintext_token,
          readonly:
        }

        encrypt_result = EncryptTokenService.new(token: payload.to_json).call
        return encrypt_result unless encrypt_result.success?

        ServiceResult.success(
          result: {
            encrypted_token: encrypt_result.result,
            resource_url:,
            readonly:,
            expires_at: access_token.expires_in.seconds.from_now.iso8601,
            expires_in_seconds: access_token.expires_in
          }
        )
      end

      private

      def resource_url
        @resource_url ||= URI.join(
          OpenProject::StaticRouting::StaticUrlHelpers.new.root_url,
          api_v3_paths.document(@document.id)
        ).to_s
      end

      def readonly
        @readonly ||= @user.allowed_in_project?(:view_documents, @project) &&
          !@user.allowed_in_project?(:manage_documents, @project)
      end
    end
  end
end
