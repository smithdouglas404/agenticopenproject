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
  class JiraFetchGroupsAndUsersJob < ApplicationJob
    include JobIteration::Iteration

    class GroupMembersEnumerator
      def initialize(jira_client, group_name:, cursor:, page_size: 30)
        @jira_client = jira_client
        @group_name = group_name
        @page = @jira_client.group_members(group_name:, start_at: cursor, max_results: page_size)
        # Jira DC has it is own page limit configuration.
        # Therefore it makes sense to respect it.
        server_page_size = @page["maxResults"]
        @page_size = if server_page_size == page_size
                       page_size
                     else
                       server_page_size
                     end
        @cursor = cursor || 0
      end

      def to_enumerator
        to_enum(:each).lazy
      end

      private

      def each
        loop do
          yield @page["values"], @page["startAt"]

          @cursor += @page_size
          @page = @jira_client.group_members(group_name: @group_name, start_at: @cursor, max_results: @page_size)
          # Jira DC has it is own page limit configuration.
          # Therefore it makes sense to respect it.
          server_page_size = @page["maxResults"]
          @page_size = if @page_size == server_page_size
                         @page_size
                       else
                         server_page_size
                       end

          break if @page["isLast"]
        end
      end
    end

    on_complete do |job|
      jira_import = Import::JiraImport.find(job.arguments.first)
      jira_import.transition_to!(:groups_and_users_fetching_done)
    end

    around_iterate do |job, block|
      block.call
      jira_import = Import::JiraImport.find(job.arguments.first)
      jira_import.update_column(:cursor, cursor_position)
    end

    rescue_from(StandardError) do |e|
      jira_import = Import::JiraImport.find(arguments.first)
      jira_import.transition_to!(:groups_and_users_fetching_error,
                                 job_id: job_id,
                                 error_backtrace: e.backtrace,
                                 error: e.message)
    end

    # rubocop:disable Metrics/AbcSize
    def build_enumerator(jira_import_id, cursor:)
      jira_import = Import::JiraImport.find(jira_import_id)
      group_names = jira_import.client.groups["groups"].pluck("name")
      enumerator_builder.nested(
        [
          ->(cursor) { enumerator_builder.array(group_names, cursor:) },
          ->(group_name, cursor) {
            enumerator_builder.wrap(
              enumerator_builder,
              GroupMembersEnumerator.new(
                jira_import.client,
                group_name:,
                page_size: 30,
                cursor:
              ).to_enumerator
            )
          }
        ],
        cursor:
      )
    end
    # rubocop:enable Metrics/AbcSize

    def each_iteration(users_batch, jira_import_id)
      jira_import = Import::JiraImport.find(jira_import_id)
      jira_client = jira_import.client
      updated_at = Time.zone.now
      created_at = updated_at
      users_upsert_data = users_batch.map do |jira_user|
        jira_user_key = jira_user.fetch("key")
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
  end
end
