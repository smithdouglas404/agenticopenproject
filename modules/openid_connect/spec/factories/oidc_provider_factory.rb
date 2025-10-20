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

FactoryBot.define do
  factory :oidc_provider, class: "OpenIDConnect::Provider" do
    sequence(:display_name) { |n| "Foobar ##{n}" }
    sequence(:slug) { |n| "oidc-foobar-#{n}" }
    limit_self_registration { true }
    creator factory: :user

    host { "https://keycloak.local" }
    issuer { "https://keycloak.local/realms/master" }
    jwks_uri { "https://keycloak.local/realms/master/protocol/openid-connect/certs" }
    client_id { "https://openproject.local" }
    client_secret { "9AWjVC3A4U1HLrZuSP4xiwHfw6zmgECn" }
    oidc_provider { "custom" }
    token_endpoint { "https://keycloak.local/realms/master/protocol/openid-connect/token" }
    userinfo_endpoint { "https://keycloak.local/realms/master/protocol/openid-connect/userinfo" }
    end_session_endpoint { "https://keycloak.local/realms/master/protocol/openid-connect/logout" }
    authorization_endpoint { "https://keycloak.local/realms/master/protocol/openid-connect/auth" }

    trait :token_exchange_capable do
      callback(:after_build) do |provider|
        provider.options["grant_types_supported"] ||= []
        provider.options["grant_types_supported"] << OpenProject::OpenIDConnect::TOKEN_EXCHANGE_GRANT_TYPE
      end
    end
  end

  factory :oidc_provider_google, class: "OpenIDConnect::Provider" do
    display_name { "Google" }
    slug { "oidc-google" }
    limit_self_registration { true }
    creator factory: :user

    options do
      { "issuer" => "https://accounts.google.com",
        "jwks_uri" => "https://www.googleapis.com/oauth2/v3/certs",
        "client_id" => "identifier",
        "client_secret" => "secret",
        "oidc_provider" => "google",
        "token_endpoint" => "https://oauth2.googleapis.com/token",
        "userinfo_endpoint" => "https://openidconnect.googleapis.com/v1/userinfo",
        "authorization_endpoint" => "https://accounts.google.com/o/oauth2/v2/auth" }
    end
  end

  factory :oidc_provider_entra, class: "OpenIDConnect::Provider" do
    display_name { "Microsoft Entra" }
    slug { "oidc-microsoft-entra" }
    limit_self_registration { false }
    creator factory: :user

    options do
      {
        "scope" => "openid email profile",
        "issuer" => "https://login.microsoftonline.com/e36f1dbc-fdae-427e-b61b-0d96ddfb81a4/v2.0",
        "tenant" => "e36f1dbc-fdae-427e-b61b-0d96ddfb81a4",
        "jwks_uri" => "https://login.microsoftonline.com/e36f1dbc-fdae-427e-b61b-0d96ddfb81a4/discovery/v2.0/keys",
        "client_id" => "client_id",
        "sync_groups" => false,
        "groups_claim" => "groups",
        "client_secret" => "client_secret",
        "group_regexes" => [],
        "oidc_provider" => "microsoft_entra",
        "group_prefixes" => [],
        "token_endpoint" => "https://login.microsoftonline.com/e36f1dbc-fdae-427e-b61b-0d96ddfb81a4/oauth2/v2.0/token",
        "userinfo_endpoint" => "https://graph.microsoft.com/oidc/userinfo",
        "end_session_endpoint" => "https://login.microsoftonline.com/e36f1dbc-fdae-427e-b61b-0d96ddfb81a4/oauth2/v2.0/logout",
        "grant_types_supported" => ["authorization_code", "implicit"],
        "authorization_endpoint" => "https://login.microsoftonline.com/e36f1dbc-fdae-427e-b61b-0d96ddfb81a4/oauth2/v2.0/authorize",
        "post_logout_redirect_uri" => ""
      }
    end
  end
end
