# frozen_string_literal: true

module ResourcePlanners
  module Forms
    class DatesForm < ApplicationForm
      form do |f|
        f.group(layout: :horizontal) do |dates|
          dates.text_field(
            name: :start_date,
            type: :date,
            label: ResourcePlanner.human_attribute_name(:start_date),
            input_width: :medium
          )
          dates.text_field(
            name: :end_date,
            type: :date,
            label: ResourcePlanner.human_attribute_name(:end_date),
            input_width: :medium
          )
        end
      end
    end
  end
end
