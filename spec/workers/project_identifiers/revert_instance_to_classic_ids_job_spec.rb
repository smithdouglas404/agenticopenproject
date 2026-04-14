# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "rails_helper"

RSpec.describe ProjectIdentifiers::RevertInstanceToClassicIdsJob do
  subject(:job) { described_class.new }

  let(:task) { BackgroundTask.create!(task_type: BackgroundTask::SEMANTIC_ID_REVERSION) }

  before do
    allow(GoodJob::Batch).to receive(:enqueue).and_yield
  end

  describe "#perform" do
    context "when there are projects to revert" do
      before { create_list(:project, 2) }

      it "transitions the task from pending to processing" do
        expect { job.perform(task.id) }
          .to change { task.reload.status }.from(BackgroundTask::PENDING).to(BackgroundTask::PROCESSING)
      end

      it "enqueues one RevertProjectToClassicIdsJob per project" do
        expect { job.perform(task.id) }
          .to have_enqueued_job(ProjectIdentifiers::RevertProjectToClassicIdsJob).exactly(2).times
      end

      it "sets FinishRevertingInstanceToClassicIdsJob as the on_success callback" do
        job.perform(task.id)
        expect(GoodJob::Batch).to have_received(:enqueue)
          .with(hash_including(on_success: ProjectIdentifiers::FinishRevertingInstanceToClassicIdsJob))
      end

      it "passes task_id as a flat batch property so the callback can complete the task" do
        job.perform(task.id)
        expect(GoodJob::Batch).to have_received(:enqueue)
          .with(hash_including(task_id: task.id))
      end

      it "does not nest task_id under on_success_params" do
        job.perform(task.id)
        expect(GoodJob::Batch).not_to have_received(:enqueue)
          .with(hash_including(on_success_params: anything))
      end
    end

    context "when there are no projects" do
      it "does not enqueue any per-project jobs" do
        expect { job.perform(task.id) }
          .not_to have_enqueued_job(ProjectIdentifiers::RevertProjectToClassicIdsJob)
      end
    end
  end
end
