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

  let(:task)  { create(:long_running_task, task_type: :semantic_id_conversion).tap(&:start!) }
  let(:batch) { instance_double(GoodJob::Batch, properties: { "task_id" => task.id }) }
  let(:finder) { instance_double(ProjectIdentifiers::PendingProjectsFinder) }

  before do
    allow(ProjectIdentifiers::PendingProjectsFinder).to receive(:new).and_return(finder)
    allow(Setting::WorkPackageIdentifier).to receive(:enable_semantic!)
  end

  describe "#perform" do
    context "when no projects remain from the start" do
      before { allow(finder).to receive(:project_ids).and_return(Set.new) }

      it "enables semantic mode without running any conversion" do
        allow(ProjectIdentifiers::ConvertProjectToSemanticService).to receive(:new)
        job.perform(batch)
        expect(ProjectIdentifiers::ConvertProjectToSemanticService).not_to have_received(:new)
        expect(Setting::WorkPackageIdentifier).to have_received(:enable_semantic!)
      end

      it "marks the task as complete" do
        job.perform(batch)
        expect(task.reload.status).to eq("complete")
      end
    end

    context "when projects are cleared after the first sweep" do
      let(:project) { instance_double(Project) }
      let(:service) { instance_double(ProjectIdentifiers::ConvertProjectToSemanticService, call: nil) }

      before do
        allow(finder).to receive(:project_ids).and_return(Set[1], Set.new)
        allow(Project).to receive(:find_by).with(id: 1).and_return(project)
        allow(ProjectIdentifiers::ConvertProjectToSemanticService).to receive(:new).with(project).and_return(service)
      end

      it "runs one conversion sweep then enables semantic mode" do
        job.perform(batch)
        expect(service).to have_received(:call).once
        expect(Setting::WorkPackageIdentifier).to have_received(:enable_semantic!)
      end
    end

    context "when projects still remain after all sweeps" do
      let(:project) { instance_double(Project) }
      let(:service) { instance_double(ProjectIdentifiers::ConvertProjectToSemanticService, call: nil) }

      before do
        allow(finder).to receive(:project_ids).and_return(Set[1])
        allow(Project).to receive(:find_by).with(id: 1).and_return(project)
        allow(ProjectIdentifiers::ConvertProjectToSemanticService).to receive(:new).with(project).and_return(service)
      end

      it "raises after MAX_SWEEPS sweeps, logging a warning and not enabling semantic mode" do
        allow(Rails.logger).to receive(:warn)
        give_up_pattern = /Giving up after #{described_class::MAX_SWEEPS} sweeps/o

        expect { job.perform(batch) }.to raise_error(RuntimeError, give_up_pattern)
        expect(service).to have_received(:call).exactly(described_class::MAX_SWEEPS).times
        expect(Rails.logger).to have_received(:warn).with(give_up_pattern)
        expect(Setting::WorkPackageIdentifier).not_to have_received(:enable_semantic!)
      end

      it "marks the task as failed" do
        allow(Rails.logger).to receive(:warn)
        expect { job.perform(batch) }.to raise_error(RuntimeError)
        expect(task.reload.status).to eq("failed")
      end
    end

    context "when a remaining project no longer exists" do
      before do
        allow(finder).to receive(:project_ids).and_return(Set[99], Set.new)
        allow(Project).to receive(:find_by).with(id: 99).and_return(nil)
        allow(ProjectIdentifiers::ConvertProjectToSemanticService).to receive(:new)
      end

      it "skips the missing project and still enables semantic mode" do
        job.perform(batch)
        expect(ProjectIdentifiers::ConvertProjectToSemanticService).not_to have_received(:new)
        expect(Setting::WorkPackageIdentifier).to have_received(:enable_semantic!)
      end
    end
  end
end
