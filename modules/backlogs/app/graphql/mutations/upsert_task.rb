# frozen_string_literal: true

module Mutations
  class UpsertTask < Mutations::BaseMutation
    description "Create or update a task"

    argument :input, Types::Inputs::TaskInput, required: true

    field :task, Types::TaskType, null: true
    field :errors, [String], null: false

    def resolve(input:)
      task =
        if input[:id].present?
          Task.find_by(id: input[:id])
        else
          Task.new
        end

      return { task: nil, errors: ["Task not found"] } if task.nil?

      # Optional: simple authorization check placeholder
      # raise GraphQL::ExecutionError, "Not authorized" unless context[:current_user]

      # ensure task belongs to the story given (esp. on update)
      if task.persisted? && task.story_id.to_s != input[:story_id].to_s
        return { task: nil, errors: ["Cannot move task to a different story"] }
      end

      task.story_id = input[:story_id]
      task.title = input[:title]
      task.done = input.key?(:done) ? input[:done] : task.done

      if task.save
        { task: task, errors: [] }
      else
        { task: nil, errors: task.errors.full_messages }
      end
    end
  end
end
