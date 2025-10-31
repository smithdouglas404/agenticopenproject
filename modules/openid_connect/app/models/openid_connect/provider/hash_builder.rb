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

module OpenIDConnect
  module Provider::HashBuilder
    STATE_GENERATOR = -> { SecureRandom.hex(42) }

    def to_omniauth_hash # rubocop:disable Metrics/AbcSize
      client_options = {
        identifier: client_id,
        secret: client_secret,
        authorization_endpoint:,
        token_endpoint:,
        userinfo_endpoint:,
        jwks_uri:,
        end_session_endpoint:,
        host: host || ::UrlBuilder.host_from_endpoint(authorization_endpoint),
        redirect_uri:
      }.compact
      {
        name: slug.to_sym,
        icon:,
        scheme:,
        port:,
        display_name:,
        issuer:,
        scope: scopes,
        attribute_map:,
        post_logout_redirect_uri:,
        claims: add_groups_claim(JSON.parse(claims.presence || "{}")).to_json,
        acr_values:,
        client_options:
      }
        .merge(provider_specific_to_h)
        .compact
    end

    def to_h
      hash = to_omniauth_hash
      hash.merge(
        limit_self_registration:,
        # Remember oidc session values when logging in user
        retain_from_session: %w[
          omniauth.oidc_sid
          omniauth.oidc_access_token
          omniauth.oidc_refresh_token
          omniauth.oidc_expires_in
          omniauth.oidc_groups
        ],
        single_sign_out_callback: single_sign_out_callback(hash),
        backchannel_logout_callback: ::OpenProject::OpenIDConnect::SessionMapper.method(:handle_logout)
      )
    end

    private

    def single_sign_out_callback(omniauth_hash)
      Proc.new do
        next unless omniauth_hash[:client_options][:end_session_endpoint]

        redirect_to "#{omni_auth_start_path(omniauth_hash[:name])}/logout"
      end
    end

    def provider_specific_to_h
      case oidc_provider
      when "google"
        {
          client_auth_method: :not_basic,
          send_nonce: false,
          state: STATE_GENERATOR
        }
      when "microsoft_entra"
        {}
      else
        {}
      end
    end

    def attribute_map
      OpenIDConnect::Provider::MAPPABLE_ATTRIBUTES
        .index_with { |attr| public_send(:"mapping_#{attr}") }
        .compact_blank
    end

    def add_groups_claim(claims)
      claims = { "id_token" => { groups_claim => nil } }.deep_merge(claims) if sync_groups
      claims
    end
  end
end
