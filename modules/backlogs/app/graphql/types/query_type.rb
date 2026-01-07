# app/graphql/types/query_type.rb
module Types
  class QueryType < Types::BaseObject
    description "The query root of this schema"

    # -----------------------------
    # Projects
    # -----------------------------

    field :projects, [Types::ProjectType], null: false do
      argument :id, ID, required: false
      argument :name, String, required: false
    end

    def projects(id: nil, name: nil)
      scope = Project.all

      scope = scope.where(id: id) if id.present?
      scope = scope.where("name ILIKE ?", "%#{name}%") if name.present?

      scope
    end

    field :project, Types::ProjectType, null: true do
      argument :id, ID, required: true
    end

    def project(id:)
      Project.find_by(id: id)
    end

    # -----------------------------
    # Backlogs
    # -----------------------------

    field :backlogs, [Types::BacklogType], null: false do
      argument :project_id, ID, required: true
      argument :type, String, required: false # "SprintBacklog" / "OwnerBacklog"
    end

    def backlogs(project_id:, type: nil)
      project = Project.find(project_id)
      owner_backlogs = Backlog.owner_backlogs(project) if type == "SprintBacklog"
      sprint_backlogs = Backlog.sprint_backlogs(project) if type == "OwnerBacklog"

      owner_backlogs + sprint_backlogs
    end

    # field :backlog, Types::BacklogType, null: true do
    #   # argument :id, ID, required: true
    # end

    # def backlog(id:)
    #   Backlog.find_by(id: id)
    # end

    # -----------------------------
    # Stories
    # -----------------------------

    field :stories, [Types::StoryType], null: false do
      argument :backlog_id, ID, required: false
      argument :assignee_id, ID, required: false
    end

    def stories(backlog_id: nil, assignee_id: nil)
      scope = Story.all

      scope = scope.where(backlog_id: backlog_id) if backlog_id.present?
      scope = scope.where(assignee_id: assignee_id) if assignee_id.present?

      scope
    end

    field :story, Types::StoryType, null: true do
      argument :id, ID, required: true
    end

    def story(id:)
      Story.find_by(id: id)
    end

    # -----------------------------
    # Tasks
    # -----------------------------

    field :tasks, [Types::TaskType], null: false do
      argument :story_id, ID, required: false
      argument :done, Boolean, required: false
    end

    def tasks(story_id: nil, done: nil)
      scope = Task.all

      scope = scope.where(story_id: story_id) if story_id.present?
      scope = scope.where(done: done) unless done.nil?

      scope
    end

    field :task, Types::TaskType, null: true do
      argument :id, ID, required: true
    end

    def task(id:)
      Task.find_by(id: id)
    end
  end
end
