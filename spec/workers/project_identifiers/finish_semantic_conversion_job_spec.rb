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

  before do
    allow(ProjectIdentifiers::PendingProjectsFinder).to receive(:new).and_return(finder)
    allow(Setting::WorkPackageIdentifier).to receive(:enable_semantic!)
  end

  describe "#perform" do
    context "when no projects remain" do
      before { allow(finder).to receive(:project_ids).and_return(Set.new) }

      it "marks the task as complete" do
        expect { job.perform(nil, { task_id: task.id }) }
          .to change { task.reload.status }.from(BackgroundTask::PROCESSING).to(BackgroundTask::COMPLETE)
      end

      it "enables semantic mode" do
        job.perform(nil, { task_id: task.id })
        expect(Setting::WorkPackageIdentifier).to have_received(:enable_semantic!)
      end

      it "does not re-run the conversion job" do
        expect(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).not_to receive(:new)
        job.perform(nil, { task_id: task.id })
      end
    end

    context "when projects still remain" do
      before { allow(finder).to receive(:project_ids).and_return(Set[1]) }

      it "synchronously re-runs ConvertInstanceToSemanticIdsJob with the task_id" do
        convert_job = instance_double(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob)
        allow(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).to receive(:new).and_return(convert_job)
        allow(convert_job).to receive(:perform)

        job.perform(nil, { task_id: task.id })

        expect(convert_job).to have_received(:perform).with(task.id)
      end

      it "still marks the task as complete" do
        allow(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).to receive(:new)
          .and_return(instance_double(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob, perform: nil))

        expect { job.perform(nil, { task_id: task.id }) }
          .to change { task.reload.status }.from(BackgroundTask::PROCESSING).to(BackgroundTask::COMPLETE)
      end

      it "still enables semantic mode" do
        allow(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).to receive(:new)
          .and_return(instance_double(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob, perform: nil))

        job.perform(nil, { task_id: task.id })
        expect(Setting::WorkPackageIdentifier).to have_received(:enable_semantic!)
      end
    end
  end
end
