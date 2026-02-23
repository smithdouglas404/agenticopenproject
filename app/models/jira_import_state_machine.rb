class JiraImportStateMachine
  include Statesman::Machine

  ### Order of states matters, because in other places we rely on it
  ### through JiraImportStateMachine.states
  state :initial, initial: true
  state :instance_meta_fetching
  state :instance_meta_error
  state :instance_meta_done

  state :groups_and_users_init

  state :groups_and_users_fetching
  state :groups_and_users_fetching_cancelling
  state :groups_and_users_fetching_cancelled
  state :groups_and_users_fetching_error
  state :groups_and_users_fetching_done

  state :groups_and_users_importing
  state :groups_and_users_importing_cancelling
  state :groups_and_users_importing_cancelled
  state :groups_and_users_importing_error
  state :groups_and_users_importing_done

  state :import_scope
  state :configuring
  state :projects_meta_fetching
  state :projects_meta_error
  state :projects_meta_done

  state :importing
  state :import_error
  state :imported
  state :completed

  state :reverting
  state :revert_error
  state :revert_cancelling
  state :revert_cancelled
  state :reverted

  transition from: INITIAL,                to: [INSTANCE_META_FETCHING]
  transition from: INSTANCE_META_FETCHING, to: [INSTANCE_META_DONE, INSTANCE_META_ERROR]
  transition from: INSTANCE_META_ERROR,    to: [INSTANCE_META_FETCHING]
  transition from: INSTANCE_META_DONE,     to: [GROUPS_AND_USERS_INIT]
  transition from: GROUPS_AND_USERS_INIT,  to: [GROUPS_AND_USERS_FETCHING]
  transition from: GROUPS_AND_USERS_FETCHING,  to: [GROUPS_AND_USERS_FETCHING_ERROR,
                                                    GROUPS_AND_USERS_FETCHING_CANCELLING,
                                                    GROUPS_AND_USERS_FETCHING_DONE]
  transition from: GROUPS_AND_USERS_FETCHING_CANCELLING,  to: [GROUPS_AND_USERS_FETCHING_CANCELLED]
  transition from: GROUPS_AND_USERS_FETCHING_ERROR, to: [GROUPS_AND_USERS_FETCHING]
  transition from: GROUPS_AND_USERS_FETCHING_DONE,  to: [GROUPS_AND_USERS_IMPORTING]
  transition from: GROUPS_AND_USERS_IMPORTING,  to: [GROUPS_AND_USERS_IMPORTING_ERROR,
                                                     GROUPS_AND_USERS_IMPORTING_DONE]
  transition from: GROUPS_AND_USERS_IMPORTING_ERROR,  to: [GROUPS_AND_USERS_IMPORTING]
  transition from: GROUPS_AND_USERS_IMPORTING_DONE,  to: [IMPORT_SCOPE]
  transition from: IMPORT_SCOPE,           to: [CONFIGURING]
  transition from: CONFIGURING,            to: [PROJECTS_META_FETCHING]
  transition from: PROJECTS_META_FETCHING, to: [PROJECTS_META_DONE, PROJECTS_META_ERROR]
  transition from: PROJECTS_META_ERROR,    to: [PROJECTS_META_FETCHING]
  transition from: PROJECTS_META_DONE,     to: [IMPORTING]
  transition from: IMPORTING,              to: [IMPORTED, IMPORT_ERROR]
  transition from: IMPORT_ERROR,           to: [IMPORTING, REVERTING]
  transition from: IMPORTED,               to: [COMPLETED, REVERTING]
  transition from: REVERTING,              to: [REVERTED, REVERT_CANCELLING, REVERT_ERROR]
  transition from: REVERT_CANCELLING,      to: [REVERT_CANCELLED]
  transition from: REVERT_CANCELLED,       to: [REVERTING]
  transition from: REVERT_ERROR,           to: [REVERTING]

  after_transition(to: :groups_and_users_fetching) do |jira_import, transition|
    JiraFetchGroupsAndUsersJob.perform_later(jira_import.id)
  end

  after_transition(to: :groups_and_users_importing) do |jira_import, transition|
    JiraImportGroupsAndUsersJob.perform_later(jira_import.id)
  end

  after_transition(to: :groups_and_users_fetching_done) do |jira_import, transition|
    jira_import.update_column(:cursor, nil)
  end

  after_transition(to: :groups_and_users_importing_done) do |jira_import, transition|
    jira_import.update_column(:cursor, nil)
  end

  after_transition(to: :reverted) do |jira_import, transition|
    jira_import.update_column(:cursor, nil)
  end

  after_transition(to: :instance_meta_fetching) do |jira_import, transition|
    JiraInstanceMetaDataJob.perform_later(jira_import.id)
  end

  after_transition(to: :projects_meta_fetching) do |jira_import, transition|
    JiraProjectsMetaDataJob.perform_later(jira_import.id)
  end

  after_transition(to: :importing) do |jira_import, transition|
    JiraFetchAndImportProjectsJob.perform_later(jira_import.id)
  end

  after_transition(to: :reverting) do |jira_import, transition|
    job = JiraRevertJiraImportJob.perform_later(jira_import.id)
    transition.metadata["job_id"] = job.job_id
    transition.save!
  end

  def status_running?
    [
      INSTANCE_META_FETCHING,
      PROJECTS_META_FETCHING,
      GROUPS_AND_USERS_FETCHING,
      GROUPS_AND_USERS_IMPORTING,
      IMPORTING,
      REVERTING
    ].include?(current_state)
  end

  def status_equal_or_after?(check_status)
    JiraImportStateMachine.states.index(current_state) >= JiraImportStateMachine.states.index(check_status)
  end

  def status_equal_or_before?(check_status)
    JiraImportStateMachine.states.index(current_state) <= JiraImportStateMachine.states.index(check_status)
  end

  def status_before?(check_status)
    JiraImportStateMachine.states.index(current_state) < JiraImportStateMachine.states.index(check_status)
  end

  def status_after?(check_status)
    JiraImportStateMachine.states.index(current_state) > JiraImportStateMachine.states.index(check_status)
  end

  def deletable?
    !status_running? && !in_state?(IMPORTED, IMPORT_ERROR, REVERT_ERROR)
  end
end
