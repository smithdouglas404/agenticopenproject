# frozen_string_literal: true

module Types
  module Inputs
    class TaskInput < Types::BaseInputObject
      argument :id, ID, required: false
      argument :story_id, ID, required: true

      argument :title, String, required: true
      argument :done, Boolean, required: false
    end
  end
end
