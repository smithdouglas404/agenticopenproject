class JiraFetchGroupsAndUsersJob < ApplicationJob
  include JobIteration::Iteration

  class GroupMembersEnumerator
    def initialize(jira_client, group_name:, page_size: 30, cursor:)
      @jira_client = jira_client
      @group_name = group_name
      @page = @jira_client.group_members(group_name:, start_at: cursor, max_results: page_size)
      File.open('progress.txt', 'a') { |f| f.write("group: #{group_name}\n") }
      # Jira DC has it is own page limit configuration.
      # Therefore it makes sense to respect it.
      server_page_size = @page["maxResults"]
      @page_size =  if server_page_size != page_size
                      server_page_size
                    else
                      page_size
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
        File.open('progress.txt', 'a') { |f| f.write("#{object_id} group: #{@group_name}\n") }
        # Jira DC has it is own page limit configuration.
        # Therefore it makes sense to respect it.
        server_page_size = @page["maxResults"]
        @page_size =  if @page_size != server_page_size
                        server_page_size
                      else
                        @page_size
                      end

        break if @page["isLast"]
      end
    end
  end

  on_complete do |job|
    jira_import = JiraImport.find(job.arguments.first)
    jira_import.transition_to!(:groups_and_users_fetching_done)
  end

  around_iterate do |job, block|
    block.call
    jira_import = JiraImport.find(job.arguments.first)
    jira_import.update_column(:cursor, cursor_position)
    File.open('progress.txt', 'a') { |f| f.write("cursor: #{cursor_position}\n") }
  end


  rescue_from(StandardError) do |e|
    jira_import = JiraImport.find(arguments.first)
    jira_import.transition_to!(:groups_and_users_fetching_error,
                                job_id: self.job_id,
                                error_backtrace: e.backtrace,
                                error: e.message)
  end

  def build_enumerator(jira_import_id, cursor:)
    jira_import = JiraImport.find(jira_import_id)
    group_names = jira_import.client.groups["groups"].map {|g| g["name"]}
    enumerator_builder.nested(
      [
        ->(cursor) {enumerator_builder.array(group_names, cursor: cursor)},
        ->(group_name, cursor) {
      enumerator_builder.wrap(
        enumerator_builder,
        GroupMembersEnumerator.new(
          jira_import.client,
          group_name:,
          page_size: 30,
          cursor: cursor
        ).to_enumerator
      )
        },
      ],
      cursor: cursor
    )
  end

  def each_iteration(users_batch, jira_import_id)
    jira_import = JiraImport.find(jira_import_id)
    jira_client = jira_import.client
    updated_at = Time.now
    created_at = updated_at
    users_upsert_data = users_batch.map do |jira_user|
      jira_user_key = jira_user.fetch('key')
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
    upsert_result = JiraUser.upsert_all(users_upsert_data, unique_by: [:jira_id, :jira_user_key])
  end
end
