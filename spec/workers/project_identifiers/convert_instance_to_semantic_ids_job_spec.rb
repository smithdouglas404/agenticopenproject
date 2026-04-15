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

RSpec.describe ProjectIdentifiers::ConvertInstanceToSemanticIdsJob,
               with_good_job_batches: [
                 ProjectIdentifiers::FinishSemanticConversionJob,
                 ProjectIdentifiers::ConvertProjectToSemanticIdsJob
               ] do
  subject(:job) { described_class.new }

  let(:task)   { LongRunningTask.create!(task_type: :semantic_id_conversion) }
  let(:finder) { instance_double(ProjectIdentifiers::PendingProjectsFinder) }

  before do
    allow(ProjectIdentifiers::PendingProjectsFinder).to receive(:new).and_return(finder)
  end

  describe "#perform" do
    context "when there are projects to convert" do
      before { allow(finder).to receive(:project_ids).and_return(Set[1, 2]) }

      it "transitions the task from pending to processing" do
        expect { job.perform(task.id) }
          .to change { task.reload.started_at }.from(nil)
      end

      it "enqueues one ConvertProjectToSemanticIdsJob per pending project" do
        job.perform(task.id)
        expect(GoodJob::Job.where(job_class: ProjectIdentifiers::ConvertProjectToSemanticIdsJob.name).count).to eq(2)
      end

      it "sets FinishSemanticConversionJob as the on_success callback" do
        allow(GoodJob::Batch).to receive(:enqueue).and_call_original
        job.perform(task.id)
        expect(GoodJob::Batch).to have_received(:enqueue)
          .with(hash_including(on_success: ProjectIdentifiers::FinishSemanticConversionJob))
      end

      it "passes task_id and attempt as flat batch properties" do
        allow(GoodJob::Batch).to receive(:enqueue).and_call_original
        job.perform(task.id, attempt: 2)
        expect(GoodJob::Batch).to have_received(:enqueue)
          .with(hash_including(task_id: task.id, attempt: 2))
      end
    end

    context "when the task is already processing (synchronous re-run)" do
      before do
        task.start!
        allow(finder).to receive(:project_ids).and_return(Set[1])
      end

      it "does not call start! again" do
        expect { job.perform(task.id) }.not_to change { task.reload.started_at }
      end
    end

    context "when there are no projects to convert" do
      before { allow(finder).to receive(:project_ids).and_return(Set.new) }

      it "does not enqueue any per-project jobs" do
        job.perform(task.id)
        expect(GoodJob::Job.where(job_class: ProjectIdentifiers::ConvertProjectToSemanticIdsJob.name)).not_to exist
      end
    end
  end
end
