# frozen_string_literal: true

class AddShownInColumnToCfSection < ActiveRecord::Migration[8.0]
  def change
    add_column :custom_field_sections,
               :shown_in,
               :string,
               default: CustomFieldSection::DEFAULT_SHOWN_IN_KEY,
               null: false
  end
end
