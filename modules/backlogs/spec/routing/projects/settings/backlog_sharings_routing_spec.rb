# frozen_string_literal: true

require "spec_helper"

RSpec.describe Projects::Settings::BacklogSharingsController do
  describe "routing" do
    context "with the feature flag active", with_flag: { scrum_projects: true } do
      it {
        expect(get("/projects/project_42/settings/backlog_sharing")).to route_to(
          controller: "projects/settings/backlog_sharings",
          action: "show",
          project_id: "project_42"
        )
      }

      it {
        expect(patch("/projects/project_42/settings/backlog_sharing")).to route_to(
          controller: "projects/settings/backlog_sharings",
          action: "update",
          project_id: "project_42"
        )
      }
    end

    context "with the feature flag inactive", with_flag: { scrum_projects: false } do
      it { expect(get("/projects/project_42/settings/backlog_sharing")).not_to be_routable }
      it { expect(patch("/projects/project_42/settings/backlog_sharing")).not_to be_routable }
    end
  end
end
