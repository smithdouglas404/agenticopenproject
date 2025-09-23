# frozen_string_literal: true

class ConvertProjectToCustomizedInCalculatedValueErrors < ActiveRecord::Migration[8.0]
  def up
    rename_column :calculated_value_errors, :project_id, :customized_id
    add_column :calculated_value_errors, :customized_type, :string, null: false

    CalculatedValueError.reset_column_information # Reload schema
    CalculatedValueError.update_all(customized_type: "Project")

    remove_index :calculated_value_errors, name: "index_unique_calc_val_error_per_project_and_cf"

    add_index :calculated_value_errors,
              %i[customized_type customized_id custom_field_id error_code],
              unique: true,
              name: "index_unique_calc_val_error_per_customized_and_cf"
  end

  def down
    rename_column :calculated_value_errors, :customized_id, :project_id
    remove_column :calculated_value_errors, :customized_type

    remove_index :calculated_value_errors, name: "index_unique_calc_val_error_per_project_and_cf"

    add_index :calculated_value_errors,
              %i[project_id custom_field_id error_code],
              unique: true,
              name: "index_unique_calc_val_error_per_project_and_cf"
  end
end
