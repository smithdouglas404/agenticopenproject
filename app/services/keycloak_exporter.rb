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

class KeycloakExporter
  ROOT_GROUP_NAME = "OpenProject Import"

  attr_reader :client

  def initialize(client)
    @client = client
  end

  def call(start: nil)
    # TODO: temporarily disable "Configure OTP"

    Group.find_each do |group|
      log("Uploading group #{group.name} (#{group.id})...")
      client.create_group(name: group.name, parent_id: root_group_id)
    end

    User.active.includes(:passwords, :otp_devices, :otp_backup_codes, :groups).find_each(start:) do |user|
      next if client.users_by_email(user.mail).present?

      log("Uploading user #{user.id}...")
      result = client.create_user(user, group_prefix: "/#{ROOT_GROUP_NAME}/")
      log("User was already present, upload failed!") if result == :conflict
    end
  end

  private

  def log(message)
    Rails.logger.info(message)
  end

  def root_group_id
    @root_group_id ||= begin
      client.create_group(name: ROOT_GROUP_NAME)
      client.groups_by_name(ROOT_GROUP_NAME).first&.fetch("id")
    end
  end
end
