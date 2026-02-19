# frozen_string_literal: true

class AddUserNonWorkingDays < ActiveRecord::Migration[8.1]
  def change
    create_table :user_non_working_days do |t|
      t.references :user, null: false, foreign_key: true

      t.date :date, null: false, index: true

      t.timestamps

      t.index %i[user_id date], unique: true
    end
  end
end
