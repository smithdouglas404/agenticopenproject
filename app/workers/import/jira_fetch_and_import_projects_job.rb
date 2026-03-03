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
  class JiraFetchAndImportProjectsJob < ApplicationJob
    include Import::JiraOpenProjectReferenceCreation

    def perform(jira_import_id)
      jira_import = Import::JiraImport.find(jira_import_id)

      Import::JiraFetchProjectsJob.perform_now(jira_import_id)
      fetch_and_save_users_data(jira_import)

      Journal::NotificationConfiguration.with(false) do
        import_users(jira_import)
        Import::JiraImportProjectsJob.perform_now(jira_import_id)
      end

      jira_import.transition_to!(:imported)
    rescue StandardError => e
      jira_import&.transition_to!(:import_error, error: e.message)
      jira_import&.update!(job_id: nil, error: e.message)
    end

    private

    # rubocop:disable Metrics/AbcSize
    def fetch_and_save_users_data(jira_import)
      user_keys = Set.new
      JiraIssue.find_each do |issue|
        payload = issue.payload["fields"]
        payload
          .slice("creator", "reporter", "assignee")
          .each_value { |v| user_keys << v["key"] if v.present? }
        payload["comment"]["comments"].each { |c| user_keys << c["author"]["key"] }
      end

      jira_client = jira_import.client
      updated_at = Time.zone.now
      created_at = updated_at
      users_upsert_data = user_keys.map do |jira_user_key|
        # here we send a direct user request to get group memberships
        # which are not returned by users_search endpoint
        jira_user_by_key = jira_client.user_by_key(key: jira_user_key)
        {
          payload: jira_user_by_key,
          jira_id: jira_import.jira_id,
          jira_import_id: jira_import.id,
          jira_user_key:,
          created_at:,
          updated_at:
        }
      end
      Import::JiraUser.upsert_all(users_upsert_data, unique_by: %i[jira_id jira_user_key])
    end
    # rubocop:enable Metrics/AbcSize

    def import_users(jira_import)
      Import::JiraUser.where(jira_import_id: jira_import.id).find_each do |jira_user|
        import_user(jira_user, jira_import)
      end
    end

    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/AbcSize
    def import_user(jira_user, jira_import)
      call = Users::CreateService
               .new(user: User.system)
               .call(jira_user.to_op_attributes)

      call.on_success do |_result|
        create_reference!(
          op_leg: call.result,
          jira_leg: jira_user,
          jira_import:,
          uses_existing: false
        )
      end
      call.on_failure do |_result|
        if call.errors.find { |error| error.type == :taken }.present?
          user = jira_user.try_to_find_existing_op_users.first
          if user.present?
            create_reference!(
              op_leg: user,
              jira_leg: jira_user,
              jira_import:,
              uses_existing: true
            )
          else
            raise "Existing User is expected to be found, because there was an email " \
                  "or login collision. See attributes: #{jira_user.to_op_attributes}"
          end
        else
          raise call.message
        end
      end

      jira_user_groups = jira_user.payload["groups"]["items"].pluck("name")

      jira_user_groups.each do |group_name|
        call = Groups::CreateService
                 .new(user: User.system)
                 .call(name: group_name)
        call.on_success do |result|
          group = result.result
          create_reference!(
            op_leg: group,
            jira_leg: nil,
            jira_import:,
            uses_existing: false
          )
        end
        call.on_failure do |_result|
          if call.errors.find { |error| error.type == :taken }.present?
            group = Group.where(name: group_name).first
            if group.present?
              create_reference!(
                op_leg: group,
                jira_leg: nil,
                jira_import:,
                uses_existing: true
              )
            else
              raise "Existing Group is expected to be found. Group name: #{group_name}"
            end
          else
            raise call.message
          end
        end
        member_id = Import::JiraOpenProjectReference.where(
          jira_import_id: jira_import.id,
          jira_entity_id: jira_user.id,
          jira_entity_class: jira_user.class.to_s
        ).pick(:op_entity_id)
        group = Group.find_by!(name: group_name)
        Groups::AddUsersService
          .new(group, current_user: User.system)
          .call(ids: [member_id], send_notifications: false)
      end
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/AbcSize
  end
end
