# frozen_string_literal: true

require "rails_helper"

RSpec.describe Backlogs::BulkMovesController do
  current_user { user }

  let(:user) { create(:admin) }
  let(:project) { create(:project) }
  let(:sprint) { create(:sprint, project:) }
  let(:target_sprint) { create(:sprint, project:) }
  let!(:first_story) { create(:work_package, project:, sprint:, position: 1) }
  let!(:second_story) { create(:work_package, project:, sprint:, position: 2) }
  let!(:target_story) { create(:work_package, project:, sprint: target_sprint, position: 1) }

  describe "PUT #move" do
    subject(:move_block) do
      put :move,
          params: {
            project_id: project.id,
            source_id: "sprint:#{sprint.id}",
            target_id: "sprint:#{target_sprint.id}",
            prev_id: target_story.id,
            work_package_ids: [first_story.id, second_story.id]
          },
          format: :turbo_stream
    end

    it "moves the selected work packages as one ordered block", :aggregate_failures do
      move_block

      expect(response).to be_successful
      expect(response).to have_turbo_stream action: "replace",
                                            target: "backlogs-sprint-component-#{sprint.id}"
      expect(response).to have_turbo_stream action: "replace",
                                            target: "backlogs-sprint-component-#{target_sprint.id}"
      expect(first_story.reload.sprint).to eq(target_sprint)
      expect(second_story.reload.sprint).to eq(target_sprint)
      expect(first_story.position).to be < second_story.position
    end

    context "when one update fails" do
      let(:failed_result) { ServiceResult.failure(message: "Move failed") }
      let(:successful_result) { ServiceResult.success(result: first_story) }

      before do
        service = instance_double(Stories::UpdateService)

        allow(Stories::UpdateService).to receive(:new).and_return(service)
        allow(service).to receive(:call).and_return(successful_result, failed_result)
      end

      it "rolls back the whole selected block" do
        expect { move_block }
          .to(not_change { first_story.reload.sprint_id })

        expect(second_story.reload.sprint_id).to eq(sprint.id)

        expect(response).to have_http_status :unprocessable_entity
      end
    end
  end
end
