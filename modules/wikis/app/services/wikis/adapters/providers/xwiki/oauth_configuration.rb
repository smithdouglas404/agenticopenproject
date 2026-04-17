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
        # OAuth2 configuration for XWiki's OIDC Provider extension.
        #
        # XWiki specifics that differ from a standard OAuth2 confidential client:
        #
        # 1. Public client — XWiki's OIDC Provider does not issue client secrets.
        #    token_endpoint_auth_method is therefore :none (no secret in token requests).
        #    oauth_client.client_secret is intentionally left blank.
        #
        # 2. No client pre-registration required — XWiki's authorization endpoint accepts
        #    any client_id and redirect_uri without validation. On first authorization the
        #    user sees a consent screen; XWiki stores the consent keyed by client_id +
        #    redirect_uri. Subsequent token exchanges look up that consent.
        #    oauth_client.client_id is an OP-generated UUID used only for routing (it
        #    appears in the callback URL path so OpenProject can look up the correct
        #    OAuthClient on return).
        #
        # 3. No refresh tokens — XWiki does not include a refresh_token in token responses.
        #    Tokens are long-lived and remain valid until the user manually revokes them
        #    in their XWiki profile. Re-authorization via ensure_connection is required
        #    if a token is revoked.
        #
        # Improvement opportunities:
        # - PKCE (RFC 7636): XWiki's OIDC Provider currently does not advertise
        #   code_challenge_methods_supported. When support is added, extend
        #   authorization_uri to include code_challenge and pass code_verifier
        #   through the token exchange to eliminate the public-client security gap.
        # - Endpoint discovery: replace hardcoded endpoint paths with values fetched
        #   from <xwiki_url>/oidc/.well-known/openid-configuration and cached on the
        #   provider record, so XWiki upgrades that move endpoints don't break the
        #   integration.
        class OAuthConfiguration
          include Dry::Monads[:result]

          AUTHORIZATION_ENDPOINT = "/oidc/authorization"
          TOKEN_ENDPOINT         = "/oidc/token"
          USERINFO_ENDPOINT      = "/oidc/userinfo"

          attr_reader :oauth_client

          def initialize(wiki_provider)
            raise ArgumentError, "XWikiProvider must have a configured OAuth client" if wiki_provider.oauth_client.blank?

            @wiki_provider = wiki_provider
            @oauth_client  = wiki_provider.oauth_client.freeze
          end

          # XWiki does not issue refresh tokens. Callers should redirect to
          # ensure_connection rather than attempting a silent token refresh.
          def refresh_token_supported? = false

          def scope = %w[openid]

          def authorization_uri(state: nil)
            basic_rack_oauth_client.authorization_uri(scope:, state:)
          end

          def basic_rack_oauth_client
            uri = provider_uri

            Rack::OAuth2::Client.new(
              # XWiki is a public client — no secret is used.
              identifier:             @oauth_client.client_id,
              redirect_uri:           @oauth_client.redirect_uri,
              scheme:                 uri.scheme,
              host:                   uri.host,
              port:                   uri.port,
              authorization_endpoint: endpoint_path(AUTHORIZATION_ENDPOINT),
              token_endpoint:         endpoint_path(TOKEN_ENDPOINT)
            )
          end

          def extract_origin_user_id(token)
            response = fetch_userinfo(token.access_token)
            return Failure("XWiki userinfo request failed (#{response.code})") unless response.is_a?(Net::HTTPSuccess)

            body = JSON.parse(response.body)
            return Failure("XWiki userinfo response missing sub claim") if body["sub"].blank?

            Success(body["sub"])
          rescue StandardError => e
            Failure(e.message)
          end

          private

          def fetch_userinfo(access_token)
            uri     = URI.parse("#{@wiki_provider.url.chomp('/')}/oidc/userinfo")
            http    = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = uri.scheme == "https"

            request = Net::HTTP::Get.new(uri.request_uri)
            request["Authorization"] = "Bearer #{access_token}"
            request["Accept"]        = "application/json"

            http.request(request)
          end

          def provider_uri
            URI.parse(@wiki_provider.url)
          end

          def endpoint_path(path)
            provider_uri.path.chomp("/") + path
          end
        end
      end
    end
  end
end
