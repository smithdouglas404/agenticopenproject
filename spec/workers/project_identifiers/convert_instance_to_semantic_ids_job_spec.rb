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
                 ProjectIdentifiers::ConvertInstanceToSemanticIdsJob,
                 ProjectIdentifiers::ConvertProjectToSemanticIdsJob
               ] do
  subject(:job) { described_class.new }

  let(:finder) { instance_double(ProjectIdentifiers::PendingProjectsFinder) }
  let(:task) { BackgroundTask.create!(task_type: BackgroundTask::SEMANTIC_ID_CONVERSION) }

  before do
    allow(ProjectIdentifiers::PendingProjectsFinder).to receive(:new).and_return(finder)
  end

  describe "#perform" do
    context "when there is nothing to backfill" do
      before { allow(finder).to receive(:project_ids).and_return(Set.new) }

      it "transitions the task from pending to processing" do
        expect { job.perform(nil, { task_id: task.id }) }
          .to change { task.reload.status }.from(BackgroundTask::PENDING).to(BackgroundTask::PROCESSING)
      end

      it "flips the setting to semantic" do
        allow(Setting::WorkPackageIdentifier).to receive(:enable_semantic!)
        job.perform(nil, { task_id: task.id })
        expect(Setting::WorkPackageIdentifier).to have_received(:enable_semantic!)
      end

      it "does not create a batch" do
        allow(Setting::WorkPackageIdentifier).to receive(:enable_semantic!)
        job.perform(nil, { task_id: task.id })
        expect(GoodJob::Job.where(job_class: ProjectIdentifiers::ConvertProjectToSemanticIdsJob.name)).not_to exist
      end
    end

    context "when projects need backfill" do
      before do
        allow(finder).to receive(:project_ids).and_return(Set[1, 2])
        job.perform(nil, { task_id: task.id })
      end

      it "enqueues one BackfillProjectJob per pending project" do
        expect(GoodJob::Job.where(job_class: ProjectIdentifiers::ConvertProjectToSemanticIdsJob.name).count).to eq(2)
      end
    end

    # Callback path — invoked by GoodJob as an on_success batch callback after BackfillProjectJobs finish.
    context "when called as a batch callback (iteration >= 1)" do
      before { task.start! }

      context "when no projects remain unprocessed" do
        before { allow(finder).to receive(:project_ids).and_return(Set.new) }

        it "does not call start! again (task is already processing)" do
          expect(task).not_to receive(:start!)
          job.perform(nil, { task_id: task.id, iteration: 1 })
        end

        it "flips the setting to semantic" do
          allow(Setting::WorkPackageIdentifier).to receive(:enable_semantic!)
          job.perform(nil, { task_id: task.id, iteration: 1 })
          expect(Setting::WorkPackageIdentifier).to have_received(:enable_semantic!)
        end
      end

      context "when projects still remain" do
        before { allow(finder).to receive(:project_ids).and_return(Set[1]) }

        it "does not flip the setting" do
          job.perform(nil, { task_id: task.id, iteration: 1 })
          expect(Setting.work_packages_identifier).not_to eq(Setting::WorkPackageIdentifier::SEMANTIC)
        end

        it "re-enqueues BackfillProjectJobs for the remaining projects" do
          job.perform(nil, { task_id: task.id, iteration: 1 })
          expect(GoodJob::Job.where(job_class: ProjectIdentifiers::ConvertProjectToSemanticIdsJob.name).count).to eq(1)
        end
      end

      context "when remaining items exist but MAX_ITERATIONS has been reached" do
        before { allow(finder).to receive(:project_ids).and_return(Set[1]) }

        it "does not flip the setting and triggers a revert" do
          job.perform(nil, { task_id: task.id, iteration: described_class::MAX_ITERATIONS })
          expect(Setting.work_packages_identifier).not_to eq(Setting::WorkPackageIdentifier::SEMANTIC)
          expect(GoodJob::Job.where(job_class: ProjectIdentifiers::RevertInstanceToClassicIdsJob.name)).to exist
        end

        it "creates a SEMANTIC_ID_REVERSION task before triggering the revert" do
          expect { job.perform(nil, { task_id: task.id, iteration: described_class::MAX_ITERATIONS }) }
            .to change { BackgroundTask.where(task_type: BackgroundTask::SEMANTIC_ID_REVERSION).count }.by(1)
        end

        it "logs an error before triggering the revert" do
          allow(Rails.logger).to receive(:error)
          job.perform(nil, { task_id: task.id, iteration: described_class::MAX_ITERATIONS })
          expect(Rails.logger).to have_received(:error).with(a_string_including("max iterations"))
        end
      end

      context "when remaining items exist and iteration is below MAX_ITERATIONS" do
        before { allow(finder).to receive(:project_ids).and_return(Set[1]) }

        it "increments iteration by 1 as a flat batch property for the next callback" do
          allow(GoodJob::Batch).to receive(:enqueue).and_call_original
          job.perform(nil, { task_id: task.id, iteration: 3 })
          expect(GoodJob::Batch).to have_received(:enqueue)
            .with(hash_including(iteration: 4))
        end
      end
    end
  end
end
