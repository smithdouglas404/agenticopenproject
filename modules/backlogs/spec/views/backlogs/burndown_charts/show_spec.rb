# frozen_string_literal: true

require "spec_helper"

RSpec.describe "backlogs/burndown_charts/show" do
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:role_allowed) do
    create(:project_role,
           permissions: %i[add_work_packages manage_subtasks])
  end
  let(:role_forbidden) { create(:project_role) }
  # We need to create these as some view helpers access the database
  let(:statuses) do
    create_list(:status, 3)
  end

  let(:type_task) { create(:type_task) }
  let(:type_feature) { create(:type_feature) }
  let(:issue_priority) { create(:priority) }
  let(:project) do
    project = create(:project, types: [type_feature, type_task])
    project.members = [create(:member, principal: user1, project:, roles: [role_allowed]),
                       create(:member, principal: user2, project:, roles: [role_forbidden])]
    project
  end

  let(:story_a) do
    create(:work_package, status: statuses[0],
                          project:,
                          type: type_feature,
                          sprint: sprint,
                          priority: issue_priority)
  end
  let(:story_b) do
    create(:work_package, status: statuses[1],
                          project:,
                          type: type_feature,
                          sprint: sprint,
                          priority: issue_priority)
  end
  let(:story_c) do
    create(:work_package, status: statuses[2],
                          project:,
                          type: type_feature,
                          sprint: sprint,
                          priority: issue_priority)
  end
  let(:stories) { [story_a, story_b, story_c] }
  let(:sprint) do
    create(:agile_sprint, project:, start_date: Time.zone.today - 1.week, finish_date: Time.zone.today + 1.week)
  end
  let(:task) do
    task = create(:task, project:, status: statuses[0], sprint: sprint, type: type_task)
    # This is necessary as for some unknown reason passing the parent directly
    # leads to the task searching for the parent with 'root_id' is NULL, which
    # is not the case as the story has its own id as root_id
    task.parent_id = story_a.id
    task
  end

  before do
    view.extend BurndownChartsHelper

    # We directly force the creation of stories,statuses by calling the method
    stories
  end

  describe "burndown chart" do
    it "renders a sprint with dates" do
      assign(:sprint, sprint)
      assign(:project, project)
      assign(:burndown, Burndown.new(sprint, project))
      render

      expect(view).to render_template(partial: "_burndown", count: 1)
    end

    it "renders a sprint without dates" do
      sprint.start_date = nil
      sprint.finish_date = nil
      sprint.save
      assign(:sprint, sprint)
      assign(:project, project)
      assign(:burndown, nil)

      render

      expect(view).to render_template(partial: "_burndown", count: 0)
      expect(rendered).to include(I18n.t("backlogs.burndown_charts.show.blankslate_title"))
    end
  end
end
