class JiraImportStateMachine
  include Statesman::Machine

  state :initial, initial: true
  state :instance_meta_fetching
  state :instance_meta_error
  state :instance_meta_done
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
  state :reverted

  STATES_ORDER = [
    INITIAL,
    INSTANCE_META_FETCHING,
    INSTANCE_META_ERROR,
    INSTANCE_META_DONE,
    CONFIGURING,
    PROJECTS_META_FETCHING,
    PROJECTS_META_ERROR,
    PROJECTS_META_DONE,
    IMPORTING,
    IMPORT_ERROR,
    IMPORTED,
    COMPLETED,
    REVERTING,
    REVERT_ERROR,
    REVERTED
  ].freeze

  transition from: INITIAL,                to: [INSTANCE_META_FETCHING]
  transition from: INSTANCE_META_FETCHING, to: [INSTANCE_META_DONE, INSTANCE_META_ERROR]
  transition from: INSTANCE_META_ERROR,    to: [INSTANCE_META_FETCHING]
  transition from: INSTANCE_META_DONE,     to: [CONFIGURING]
  transition from: CONFIGURING,            to: [PROJECTS_META_FETCHING]
  transition from: PROJECTS_META_FETCHING, to: [PROJECTS_META_DONE, PROJECTS_META_ERROR]
  transition from: PROJECTS_META_ERROR,    to: [PROJECTS_META_FETCHING]
  transition from: PROJECTS_META_DONE,     to: [IMPORTING]
  transition from: IMPORTING,              to: [IMPORTED, IMPORT_ERROR]
  transition from: IMPORT_ERROR,           to: [IMPORTING]
  transition from: IMPORTED,               to: [COMPLETED, REVERTING]
  transition from: REVERTING,              to: [REVERTED, REVERT_ERROR]

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
    JiraRevertJiraImportJob.perform_later(jira_import.id)
  end

  def status_running?
    [
      INSTANCE_META_FETCHING,
      PROJECTS_META_FETCHING,
      IMPORTING,
      REVERTING
    ].include?(current_state)
  end

  def status_equal_or_after?(check_status)
    STATES_ORDER.index(current_state) >= STATES_ORDER.index(check_status)
  end

  def status_equal_or_before?(check_status)
    STATES_ORDER.index(current_state) <= STATES_ORDER.index(check_status)
  end

  def status_before?(check_status)
    STATES_ORDER.index(current_state) < STATES_ORDER.index(check_status)
  end

  def status_after?(check_status)
    STATES_ORDER.index(current_state) > STATES_ORDER.index(check_status)
  end

  def deletable?
    !status_running? && !in_state?(IMPORTED, IMPORT_ERROR, REVERT_ERROR)
  end
end
