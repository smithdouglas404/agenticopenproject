# frozen_string_literal: true

require "spec_helper"

RSpec.describe Projects::SprintSharing do
  let(:project) { create(:project) }

  describe "SPRINT_SHARING_OPTIONS" do
    it "defines all supported sprint sharing options" do
      expect(described_class::SPRINT_SHARING_OPTIONS).to match_array(
        %w[share_all_projects share_subprojects no_sharing receive_shared]
      )
    end

    it "is exposed on Project" do
      expect(Project::SPRINT_SHARING_OPTIONS).to eq(described_class::SPRINT_SHARING_OPTIONS)
    end
  end

  describe "#sprint_sharing" do
    it "defaults to no_sharing" do
      expect(project.sprint_sharing).to eq("no_sharing")
    end

    it "persists configured values" do
      project.update!(sprint_sharing: "share_subprojects")

      expect(project.reload.sprint_sharing).to eq("share_subprojects")
    end
  end

  describe "scopes" do
    shared_let(:no_sharing_project) { create(:project, sprint_sharing: "no_sharing") }
    shared_let(:all_projects_sharer) { create(:project, sprint_sharing: "share_all_projects") }
    shared_let(:subprojects_sharer) { create(:project, sprint_sharing: "share_subprojects") }
    shared_let(:receiver) { create(:project, sprint_sharing: "receive_shared") }

    describe ".share_sprints_with_all_projects" do
      it "returns projects that share with all projects" do
        expect(Project.share_sprints_with_all_projects).to contain_exactly(all_projects_sharer)
      end
    end

    describe ".share_sprints_with_subprojects" do
      it "returns projects that share with subprojects" do
        expect(Project.share_sprints_with_subprojects).to contain_exactly(subprojects_sharer)
      end
    end

    describe ".receive_shared_sprints" do
      it "returns projects that receive shared sprints" do
        expect(Project.receive_shared_sprints).to contain_exactly(receiver)
      end
    end

    describe ".not_sharing_sprints" do
      it "returns projects with no sharing" do
        expect(Project.not_sharing_sprints).to contain_exactly(no_sharing_project)
      end
    end
  end

  describe "predicate methods" do
    it "#share_sprints_with_all_projects? returns true when sharing with all projects" do
      project.sprint_sharing = "share_all_projects"
      expect(project).to be_share_sprints_with_all_projects
    end

    it "#share_sprints_with_subprojects? returns true when sharing with subprojects" do
      project.sprint_sharing = "share_subprojects"
      expect(project).to be_share_sprints_with_subprojects
    end

    it "#receive_shared_sprints? returns true when receiving shared sprints" do
      project.sprint_sharing = "receive_shared"
      expect(project).to be_receive_shared_sprints
    end

    it "#not_sharing_sprints? returns true when not sharing (default)" do
      expect(project).to be_not_sharing_sprints
    end

    it "predicates return false for non-matching values" do
      project.sprint_sharing = "share_subprojects"

      expect(project).not_to be_share_sprints_with_all_projects
      expect(project).not_to be_receive_shared_sprints
      expect(project).not_to be_not_sharing_sprints
    end
  end

  describe ".global_sprint_sharer" do
    context "when no project shares with all projects" do
      it "returns nil" do
        expect(Project.global_sprint_sharer).to be_nil
      end
    end

    context "when a project shares with all projects" do
      before { project.update!(sprint_sharing: "share_all_projects") }

      it "returns that project" do
        expect(Project.global_sprint_sharer).to eq(project)
      end
    end

    context "when the sharing project is archived" do
      before { project.update!(sprint_sharing: "share_all_projects", active: false) }

      it "returns nil" do
        expect(Project.global_sprint_sharer).to be_nil
      end
    end
  end

  describe "#receive_sprints_from" do
    let(:global_sprint_sharing) { "share_all_projects" }
    let(:root_sprint_sharing) { "share_subprojects" }
    let(:parent_sprint_sharing) { "share_subprojects" }
    let(:project_sprint_sharing) { "receive_shared" }

    let!(:global_sharer) { create(:project, sprint_sharing: global_sprint_sharing) }
    let!(:root_project) { create(:project, sprint_sharing: root_sprint_sharing) }
    let!(:parent_project) { create(:project, parent: root_project, sprint_sharing: parent_sprint_sharing) }
    let!(:project) { create(:project, parent: parent_project, sprint_sharing: project_sprint_sharing) }

    # Projects that should not be returned
    shared_let(:other_project) { create(:project, sprint_sharing: "share_subprojects") }
    shared_let(:archived_global_sharer) { create(:project, :archived, sprint_sharing: "share_all_projects") }

    shared_examples "returns the project itself" do
      it "returns only itself" do
        expect(project.receive_sprints_from).to eq(project)
      end
    end

    context "when sprint_sharing is no_sharing (default)" do
      let(:project_sprint_sharing) { "no_sharing" }

      it_behaves_like "returns the project itself"
    end

    context "when sprint_sharing is share_subprojects" do
      let(:project_sprint_sharing) { "share_subprojects" }

      it_behaves_like "returns the project itself"
    end

    context "when sprint_sharing is share_all_projects" do
      let(:global_sprint_sharing) { "no_sharing" }
      let(:root_sprint_sharing) { "share_subprojects" }
      let(:parent_sprint_sharing) { "share_subprojects" }
      let(:project_sprint_sharing) { "share_all_projects" }

      it_behaves_like "returns the project itself"
    end

    context "when sprint_sharing is receive_shared" do
      let(:project_sprint_sharing) { "receive_shared" }

      context "with only a global sharer" do
        let(:global_sprint_sharing) { "share_all_projects" }
        let(:root_sprint_sharing) { "no_sharing" }
        let(:parent_sprint_sharing) { "no_sharing" }

        it "returns only the global sharer" do
          expect(project.receive_sprints_from).to eq(global_sharer)
        end
      end

      context "with a global sharer and both ancestors sharing subprojects" do
        let(:global_sprint_sharing) { "share_all_projects" }
        let(:root_sprint_sharing) { "share_subprojects" }
        let(:parent_sprint_sharing) { "share_subprojects" }

        it "returns only the closest sharing ancestor" do
          expect(project.receive_sprints_from).to eq(parent_project)
        end
      end

      context "with no sharing sources" do
        let(:global_sprint_sharing) { "no_sharing" }
        let(:root_sprint_sharing) { "no_sharing" }
        let(:parent_sprint_sharing) { "no_sharing" }

        it "returns an empty array" do
          expect(project.receive_sprints_from).to be_nil
        end
      end
    end
  end
end
