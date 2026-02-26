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

module Import
  class JiraUser < ApplicationRecord
    self.table_name = "jira_users"

    belongs_to :jira, class_name: "Import::Jira"
    belongs_to :jira_import, class_name: "Import::JiraImport"

    def self.groups
      all.map { |x| x.payload["groups"]["items"] }.flatten.uniq { |x| x["name"] }
    end

    def to_op_attributes
      firstname = payload["displayName"].split[0..-2].join(" ")
      lastname = payload["displayName"].split[-1]
      {
        login: payload["name"],
        password: SecureRandom.uuid,
        firstname:,
        lastname:,
        mail: payload["emailAddress"],
        status: payload["active"] ? :active : :locked
      }
    end

    def try_to_find_existing_op_users
      op_attributes = to_op_attributes
      User.where(login: op_attributes[:login]).or(
        User.where(mail: op_attributes[:mail])
      )
    end
  end
end
