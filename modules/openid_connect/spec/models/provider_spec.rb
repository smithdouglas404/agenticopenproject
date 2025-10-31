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
require "spec_helper"

RSpec.describe OpenIDConnect::Provider do
  let(:provider) do
    create(:oidc_provider, options: { "grant_types_supported" => supported_grant_types },
                           claims:,
                           sync_groups:,
                           groups_claim: "the-groups")
  end
  let(:supported_grant_types) { %w[authorization_code implicit] }
  let(:claims) { "" }
  let(:sync_groups) { false }

  describe "#token_exchange_capable?" do
    subject { provider.token_exchange_capable? }

    it { is_expected.to be_falsey }

    context "when the provider supports the token exchange grant" do
      let(:supported_grant_types) { %w[authorization_code implicit urn:ietf:params:oauth:grant-type:token-exchange] }

      it { is_expected.to be_truthy }
    end

    context "when supported grant types are nil (legacy providers)" do
      let(:supported_grant_types) { nil }

      it { is_expected.to be_falsey }
    end
  end

  describe "#group_matchers" do
    subject { provider.group_matchers }

    let(:provider) { create(:oidc_provider, group_prefixes:, group_regexes:) }

    context "when prefixes and regular expressions were never defined" do
      let(:group_prefixes) { nil }
      let(:group_regexes) { nil }

      it { is_expected.to eq([/(.+)/]) }
    end

    context "when prefixes and regular expressions are empty" do
      let(:group_prefixes) { [] }
      let(:group_regexes) { [] }

      it { is_expected.to eq([/(.+)/]) }
    end

    context "when prefixes were defined" do
      let(:group_prefixes) { ["a_", "b_"] }
      let(:group_regexes) { [] }

      it { is_expected.to eq([/^a_(.+)$/, /^b_(.+)$/]) }

      context "and when prefix contains regular expression special characters" do
        let(:group_prefixes) { ["pre.fix", "(prefix)"] }

        it { is_expected.to eq([/^pre\.fix(.+)$/, /^\(prefix\)(.+)$/]) }
      end
    end

    context "when regular expressions were defined" do
      let(:group_prefixes) { [] }
      let(:group_regexes) { ["[a-z_]+", "^specific_group_name$"] }

      it { is_expected.to eq([/[a-z_]+/, /^specific_group_name$/]) }
    end

    context "when prefixes and regular expressions were defined" do
      let(:group_prefixes) { ["a"] }
      let(:group_regexes) { [/b/] }

      it "prefers prefixes over regular expressions" do
        expect(subject).to eq([/^a(.+)$/])
      end
    end
  end

  describe "#to_h" do
    subject { provider.to_h }

    let(:options) { {} }

    before do
      options.stringify_keys.each do |opt, value|
        provider.options[opt] = value
      end
    end

    it "includes empty claims by default" do
      expect(subject[:claims]).to eq("{}")
    end

    context "when there are calims and acr_values" do
      let(:provider) { create(:oidc_provider, claims:, acr_values:) }
      let(:claims) do
        {
          id_token: {
            taste: {
              essential: true,
              values: ["sweet", "bitter", "salty"]
            }
          }
        }.to_json
      end
      let(:acr_values) { "silver gold" }

      it "configures basic attributes", :aggregate_failures do
        expect(subject[:issuer]).to eq(provider.issuer)
        expect(subject[:name]).to eq(provider.slug.to_sym)
      end

      it "configures client_options", :aggregate_failures do
        client_options = subject.fetch(:client_options)

        expect(client_options[:identifier]).to eq(provider.client_id)
        expect(client_options[:secret]).to eq(provider.client_secret)
        expect(client_options[:redirect_uri]).to eq(provider.callback_url)

        %i[host authorization_endpoint token_endpoint userinfo_endpoint jwks_uri end_session_endpoint].each do |attr|
          expect(client_options[attr]).to eq(provider.public_send(attr))
        end
      end

      it "even has config for claims and acr_values (regression #66217)" do
        expect(subject[:claims]).to eq(provider.claims)
        expect(subject[:acr_values]).to eq(provider.acr_values)
      end

      context "and when the claims are empty" do
        let(:claims) { "" }

        it "configures claims to be an empty JSON object" do
          expect(subject[:claims]).to eq("{}")
        end
      end
    end

    context "when provider is custom" do
      let(:provider) do
        create(
          :oidc_provider,
          display_name: "Foobar #1",
          slug: "oidc-foobar-1"
        )
      end

      it do
        expect(subject.delete(:single_sign_out_callback)).to be_a(Proc)
        expect(subject).to eq(
          {
            attribute_map: {},
            claims: "{}",
            issuer: "https://keycloak.local/realms/master",
            scope: %i[openid email profile],
            display_name: "Foobar #1",
            icon: "openid_connect/auth_provider-custom.png",
            name: :"oidc-foobar-1",
            limit_self_registration: true,
            backchannel_logout_callback: ::OpenProject::OpenIDConnect::SessionMapper.method(:handle_logout),
            retain_from_session: ["omniauth.oidc_sid", "omniauth.oidc_access_token", "omniauth.oidc_refresh_token",
                                  "omniauth.oidc_expires_in", "omniauth.oidc_groups"],
            client_options:
              { identifier: "https://openproject.local",
                secret: "9AWjVC3A4U1HLrZuSP4xiwHfw6zmgECn",
                host: "https://keycloak.local",
                authorization_endpoint: "https://keycloak.local/realms/master/protocol/openid-connect/auth",
                token_endpoint: "https://keycloak.local/realms/master/protocol/openid-connect/token",
                userinfo_endpoint: "https://keycloak.local/realms/master/protocol/openid-connect/userinfo",
                jwks_uri: "https://keycloak.local/realms/master/protocol/openid-connect/certs",
                end_session_endpoint: "https://keycloak.local/realms/master/protocol/openid-connect/logout",
                redirect_uri: "http://localhost:3000/auth/oidc-foobar-1/callback" }
          }
        )
      end
    end

    context "when provider is google" do
      let(:provider) { create(:oidc_provider_google) }

      it do
        expect(subject.delete(:single_sign_out_callback)).to be_a(Proc)
        expect(subject).to eq(
          {
            attribute_map: {},
            claims: "{}",
            issuer: "https://accounts.google.com",
            client_auth_method: :not_basic,
            display_name: "Google",
            icon: "openid_connect/auth_provider-google.png",
            name: :"oidc-google",
            scope: %i[openid email profile],
            limit_self_registration: true,
            backchannel_logout_callback: ::OpenProject::OpenIDConnect::SessionMapper.method(:handle_logout),
            retain_from_session: ["omniauth.oidc_sid", "omniauth.oidc_access_token", "omniauth.oidc_refresh_token",
                                  "omniauth.oidc_expires_in", "omniauth.oidc_groups"],
            client_options:
              { authorization_endpoint: "https://accounts.google.com/o/oauth2/v2/auth",
                token_endpoint: "https://oauth2.googleapis.com/token",
                userinfo_endpoint: "https://openidconnect.googleapis.com/v1/userinfo",
                identifier: "identifier",
                secret: "secret",
                jwks_uri: "https://www.googleapis.com/oauth2/v3/certs",
                host: "accounts.google.com",
                redirect_uri: "http://localhost:3000/auth/oidc-google/callback" },
            send_nonce: false,
            state: described_class::STATE_GENERATOR
          }
        )
      end
    end

    context "when provider is microsoft_entra" do
      let(:provider) { create(:oidc_provider_entra) }

      it do
        expect(subject.delete(:single_sign_out_callback)).to be_a(Proc)
        expect(subject).to eq(
          {
            attribute_map: {},
            claims: "{}",
            issuer: "https://login.microsoftonline.com/e36f1dbc-fdae-427e-b61b-0d96ddfb81a4/v2.0",
            scope: %i[openid email profile],
            display_name: "Microsoft Entra",
            icon: "openid_connect/auth_provider-azure.png",
            limit_self_registration: false,
            name: :"oidc-microsoft-entra",
            post_logout_redirect_uri: "",
            backchannel_logout_callback: ::OpenProject::OpenIDConnect::SessionMapper.method(:handle_logout),
            retain_from_session: ["omniauth.oidc_sid", "omniauth.oidc_access_token", "omniauth.oidc_refresh_token",
                                  "omniauth.oidc_expires_in", "omniauth.oidc_groups"],
            client_options:
            { authorization_endpoint: "https://login.microsoftonline.com/e36f1dbc-fdae-427e-b61b-0d96ddfb81a4/oauth2/v2.0/authorize",
              token_endpoint: "https://login.microsoftonline.com/e36f1dbc-fdae-427e-b61b-0d96ddfb81a4/oauth2/v2.0/token",
              userinfo_endpoint: "https://graph.microsoft.com/oidc/userinfo",
              identifier: "client_id",
              secret: "client_secret",
              jwks_uri: "https://login.microsoftonline.com/e36f1dbc-fdae-427e-b61b-0d96ddfb81a4/discovery/v2.0/keys",
              end_session_endpoint: "https://login.microsoftonline.com/e36f1dbc-fdae-427e-b61b-0d96ddfb81a4/oauth2/v2.0/logout",
              host: "login.microsoftonline.com",
              redirect_uri: "http://localhost:3000/auth/oidc-microsoft-entra/callback" }
          }
        )
      end
    end

    context "when claims were defined" do
      let(:claims) { '{"id_token":{"taste":null}}' }

      it "includes the defined claims" do
        expect(subject[:claims]).to eq(claims)
      end
    end

    context "when group sync is enabled" do
      let(:sync_groups) { true }

      it "requests the groups claim as voluntary" do
        expect(subject[:claims]).to eq('{"id_token":{"the-groups":null}}')
      end

      context "and when other claims were defined manually" do
        let(:claims) { '{"id_token":{"taste":null}}' }

        it "merges the manual claims and the groups claim" do
          expect(subject[:claims]).to eq('{"id_token":{"the-groups":null,"taste":null}}')
        end
      end

      context "and when the groups claim was defined manually" do
        let(:claims) { '{"id_token":{"the-groups":{"essential":true}}}' }

        it "takes the manual definition of the groups claim with precedence" do
          expect(subject[:claims]).to eq(claims)
        end
      end
    end

    describe "with acr_values" do
      let(:options) { { acr_values: "phr" } }

      it "includes the acr values" do
        expect(subject[:acr_values]).to eq "phr"
      end
    end

    describe "with mapped attributes" do
      let(:options) do
        {
          mapping_email: :address,
          mapping_login: :logout,
          mapping_first_name: :given_name,
          mapping_last_name: :surname
        }
      end

      let(:expected_value) do
        {
          email: :address,
          login: :logout,
          first_name: :given_name,
          last_name: :surname
        }
      end

      it "contains the resulting attribute map being passed to omniauth-openid-connect" do
        expect(subject[:attribute_map]).to eq expected_value
      end

      it "does not turn them into superfluous attributes" do
        expect(subject).not_to include :email
        expect(subject).not_to include :login
        expect(subject).not_to include :first_name
        expect(subject).not_to include :last_name
      end
    end

    describe "with post_logout_redirect_uri" do
      let(:options) { { post_logout_redirect_uri: "https://www.openproject.org" } }

      it "contains the option" do
        expect(subject[:post_logout_redirect_uri]).to eq options[:post_logout_redirect_uri]
      end
    end
  end
end
