module OpenProjectJiraReferenceCreation
  private

  def create_reference!(op_leg:, jira_leg:, jira_import:, uses_existing:)
    OpenProjectJiraReference.insert_all(
      [
        op_entity_id: op_leg.id,
        op_entity_class: op_leg.class.to_s,
        jira_entity_id: jira_leg&.id,
        jira_entity_class: jira_leg&.class&.to_s,
        jira_import_id: jira_import.id,
        jira_id: jira_import.jira.id,
        uses_existing:
      ],
      unique_by: %i[op_entity_id op_entity_class]
    )
  end
end
