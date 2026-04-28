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

class KeycloakRestClient
  URI_MATCHER = %r{^(https?://.+)/realms/([\w-]+)/protocol/openid-connect/token$}

  ACTION_CONFIGURE_TOTP = "CONFIGURE_TOTP"
  ACTION_CONFIGURE_BACKUP_CODES = "CONFIGURE_RECOVERY_AUTHN_CODES"

  def self.from_openid_connect_provider(provider, realm: nil)
    match = URI_MATCHER.match(provider.token_endpoint)
    raise "Can't parse Base URL from #{provider.token_endpoint}" unless match

    new(
      base_uri: match[1],
      client_id: provider.client_id,
      client_secret: provider.client_secret,
      auth_realm: match[2],
      realm: realm || match[2]
    )
  end

  def initialize(base_uri:, client_id:, client_secret:, realm: "master", auth_realm: realm)
    @base_uri = base_uri
    @client_id = client_id
    @client_secret = client_secret
    @auth_realm = auth_realm
    @realm = realm

    @enabled_actions = Set.new
    @default_actions = Set.new
    list_required_actions.each do |action|
      name = action.fetch("alias")
      @enabled_actions << name if action.fetch("enabled")
      @default_actions << name if action.fetch("defaultAction")
    end
  end

  def action_enabled?(action)
    @enabled_actions.include?(action)
  end

  def action_default?(action)
    @default_actions.include?(action)
  end

  def users_by_email(email)
    get("users", params: { email:, exact: true })
  end

  def groups_by_name(name)
    get("groups", params: { search: name, exact: true })
  end

  def create_user(user, required_actions: [], group_prefix: nil)
    credentials = []
    if user.current_password
      credentials << credential_for_password_hash(user.current_password.hashed_password)
    end

    otp_devices = user.otp_devices.select { |d| d.channel == :totp }
    if otp_devices.any?
      otp_devices.each { |device| credentials << credential_for_totp_device(device) }
    elsif action_enabled?(ACTION_CONFIGURE_TOTP)
      required_actions << ACTION_CONFIGURE_TOTP
    end

    if action_enabled?(ACTION_CONFIGURE_BACKUP_CODES) && user.otp_backup_codes.any?
      required_actions << ACTION_CONFIGURE_BACKUP_CODES
    end

    groups = if group_prefix.present?
               user.groups.map { |g| "#{group_prefix}#{g.name}" }
             else
               []
             end

    payload = {
      enabled: true,
      username: user.login,
      firstName: user.firstname,
      lastName: user.lastname,
      email: user.mail,
      credentials:,
      requiredActions: required_actions,
      groups:
    }

    response = post_json("users", payload)
    handle_create_response(response)
  end

  def create_group(name:, parent_id: nil)
    path = if parent_id.present?
             "groups/#{parent_id}/children"
           else
             "groups"
           end

    response = post_json(path, { name: })
    handle_create_response(response)
  end

  private

  def list_required_actions
    get("authentication/required-actions")
  end

  def httpx
    OpenProject.httpx.oauth_auth(
      issuer: @base_uri,
      token_endpoint: "#{@base_uri}/realms/#{@auth_realm}/protocol/openid-connect/token",
      client_id: @client_id,
      client_secret: @client_secret,
      scope: "basic"
    ).with_access_token
  end

  def get(path, params: nil)
    JSON.parse(httpx.get("#{@base_uri}/admin/realms/#{@realm}/#{path}", params:).to_s)
  end

  def post_json(path, payload)
    httpx.post(
      "#{@base_uri}/admin/realms/#{@realm}/#{path}",
      headers: {
        "Content-Type": "application/json"
      },
      body: payload.to_json
    )
  end

  def handle_create_response(response)
    case response.status
    when 409
      :conflict
    when 200..299
      :ok
    else
      raise "Unexpected response from Keycloak: HTTP #{response.status}"
    end
  end

  def credential_for_password_hash(password_hash)
    _, _version, iterations, = password_hash.split("$")

    {
      "type" => "password",
      "userLabel" => "imported password",
      "credentialData" => { algorithm: "bcrypt", hashIterations: iterations.to_i }.to_json,
      "secretData" => { value: password_hash, salt: "" }.to_json
    }
  end

  def credential_for_totp_device(device)
    {
      "type" => "otp",
      "userLabel" => device.identifier,
      "secretData" => { value: device.otp_secret }.to_json,
      "credentialData" => {
        subType: "totp",
        digits: 6,
        counter: 0,
        period: 30,
        algorithm: "HmacSHA1",
        secretEncoding: "BASE32"
      }.to_json
    }
  end
end
