class AddStartedAtAndDoneAt < ActiveRecord::Migration[7.0]
  def change
    add_column :work_packages, :started_at, :datetime
    add_column :work_packages, :done_at, :datetime
  end
end
