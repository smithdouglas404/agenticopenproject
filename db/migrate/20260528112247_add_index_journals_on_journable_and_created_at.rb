# frozen_string_literal: true

class AddIndexJournalsOnJournableAndCreatedAt < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :journals,
              %i[journable_type journable_id created_at id],
              order: { created_at: :desc, id: :desc },
              name: "index_journals_on_journable_and_created_at",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
