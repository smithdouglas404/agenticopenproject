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

RSpec.describe ProjectIdentifiers::FinishSemanticConversionJob do
  subject(:job) { described_class.new }

  let(:task)   { BackgroundTask.create!(task_type: BackgroundTask::SEMANTIC_ID_CONVERSION).tap(&:start!) }
  let(:finder) { instance_double(ProjectIdentifiers::PendingProjectsFinder) }

  def batch_double(attempt: 1)
    instance_double(GoodJob::Batch, properties: { "task_id" => task.id, "attempt" => attempt })
  end

  before do
    allow(ProjectIdentifiers::PendingProjectsFinder).to receive(:new).and_return(finder)
    allow(Setting::WorkPackageIdentifier).to receive(:enable_semantic!)
    allow(ProjectIdentifiers::RevertInstanceToClassicIdsJob).to receive(:perform_later)
  end

  describe "#perform" do
    context "when no projects remain" do
      before { allow(finder).to receive(:project_ids).and_return(Set.new) }

      it "marks the task as complete" do
        expect { job.perform(batch_double, { event: :success }) }
          .to change { task.reload.status }.to(BackgroundTask::COMPLETE)
      end

      it "enables semantic mode" do
        job.perform(batch_double, { event: :success })
        expect(Setting::WorkPackageIdentifier).to have_received(:enable_semantic!)
      end

      it "does not re-run the conversion job" do
        allow(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).to receive(:new)
        job.perform
        expect(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).not_to have_received(:new)
      end
    end

    context "when projects still remain and attempts are below the limit" do
      before { allow(finder).to receive(:project_ids).and_return(Set[1]) }

      it "synchronously re-runs ConvertInstanceToSemanticIdsJob with incremented attempt" do
        convert_job = instance_double(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob)
        allow(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).to receive(:new).and_return(convert_job)
        allow(convert_job).to receive(:perform)

        job.perform(batch_double(attempt: 1), { event: :success })

        expect(convert_job).to have_received(:perform).with(task.id, attempt: 2)
      end

      it "does not enable semantic mode" do
        convert_job = instance_double(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob)
        allow(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).to receive(:new).and_return(convert_job)
        allow(convert_job).to receive(:perform)

        job.perform(batch_double(attempt: 1), { event: :success })

        expect(Setting::WorkPackageIdentifier).not_to have_received(:enable_semantic!)
      end

      it "does not mark the task as complete" do
        convert_job = instance_double(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob)
        allow(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).to receive(:new).and_return(convert_job)
        allow(convert_job).to receive(:perform)

        job.perform(batch_double(attempt: 1), { event: :success })

        expect(task.reload.status).to eq(BackgroundTask::PROCESSING)
      end
    end

    context "when projects still remain and MAX_ATTEMPTS is reached" do
      before { allow(finder).to receive(:project_ids).and_return(Set[1]) }

      let(:max_attempt_batch) { batch_double(attempt: described_class::MAX_ATTEMPTS) }

      it "marks the task as failed" do
        expect { job.perform(max_attempt_batch, { event: :success }) }
          .to change { task.reload.status }.to(BackgroundTask::FAILED)
      end

      it "triggers a revert to classic mode" do
        job.perform(max_attempt_batch, { event: :success })
        expect(ProjectIdentifiers::RevertInstanceToClassicIdsJob).to have_received(:perform_later)
      end

      it "does not enable semantic mode" do
        job.perform(max_attempt_batch, { event: :success })
        expect(Setting::WorkPackageIdentifier).not_to have_received(:enable_semantic!)
      end

      it "does not re-run the conversion job" do
        expect(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).not_to receive(:new)
        job.perform(max_attempt_batch, { event: :success })
      end
    end

    context "when called without a batch (no task tracking)" do
      before { allow(finder).to receive(:project_ids).and_return(Set.new) }

      it "does not raise" do
        expect { job.perform }.not_to raise_error
      end

      it "still enables semantic mode" do
        job.perform
        expect(Setting::WorkPackageIdentifier).to have_received(:enable_semantic!)
      end
    end
  end
end
