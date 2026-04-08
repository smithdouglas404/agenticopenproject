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
                 ProjectIdentifiers::BackfillProjectJob
               ] do
  subject(:job) { described_class.new }

  # Simulate legacy (classic) mode — the WP after_create hook does not auto-assign sequence numbers,
  # so WPs start with sequence_number: nil and identifier: nil.
  before do
    allow(Setting::WorkPackageIdentifier).to receive_messages(semantic?: false, classic?: true)
  end

  describe "#perform" do
    context "when there is nothing to backfill (all projects already have valid identifiers and all WPs have sequence numbers)" do
      it "flips the setting immediately without creating a batch" do
        job.perform
        expect(Setting.work_packages_identifier).to eq(Setting::WorkPackageIdentifier::SEMANTIC)
        expect(GoodJob::Job.where(job_class: ProjectIdentifiers::BackfillProjectJob.name)).not_to exist
      end
    end

    context "when projects have legacy (non-semantic) identifiers" do
      let!(:project_a) { create(:project, name: "My Project") }
      let!(:project_b) { create(:project, name: "Another Project") }

      before { job.perform }

      it "enqueues one BackfillProjectJob per project that needs work" do
        enqueued = GoodJob::Job.where(job_class: ProjectIdentifiers::BackfillProjectJob.name)
        expect(enqueued.count).to eq(2)
      end
    end

    context "when a project has no work packages needing backfill" do
      let!(:project_with_wp)    { create(:project, name: "Has Work") }
      let!(:project_without_wp) { create(:project, name: "Empty Project").tap { |p| p.update_columns(identifier: "EMPTY01") } }
      let!(:wp)                 { create(:work_package, project: project_with_wp) }

      before { job.perform }

      it "does not enqueue a BackfillProjectJob for the empty project" do
        enqueued_ids = GoodJob::Job
          .where(job_class: ProjectIdentifiers::BackfillProjectJob.name)
          .map { |j| j.serialized_params.dig("arguments", 0) }
        expect(enqueued_ids).not_to include(project_without_wp.id)
      end
    end

    # Callback path — invoked by GoodJob as an on_success batch callback after BackfillProjectJobs finish.
    context "when called as a batch callback (iteration >= 1)" do
      context "when no projects or work packages remain unprocessed" do
        it "flips the setting to semantic" do
          job.perform(nil, {})
          expect(Setting.work_packages_identifier).to eq(Setting::WorkPackageIdentifier::SEMANTIC)
        end
      end

      context "when work packages with sequence_number: nil remain" do
        let!(:project) { create(:project) }
        let!(:wp)      { create(:work_package, project:) }

        before { job.perform(nil, {}) }

        it "does not flip the setting" do
          expect(Setting.work_packages_identifier).not_to eq(Setting::WorkPackageIdentifier::SEMANTIC)
        end

        it "re-enqueues a BackfillProjectJob for the project with unprocessed work packages" do
          enqueued_ids = GoodJob::Job
            .where(job_class: ProjectIdentifiers::BackfillProjectJob.name)
            .map { |j| j.serialized_params.dig("arguments", 0) }
          expect(enqueued_ids).to include(project.id)
        end
      end

      context "when a project has a problematic identifier" do
        let!(:project) { create(:project).tap { |p| p.update_columns(identifier: "has-dashes") } }
        let!(:wp)      { create(:work_package, project:) }

        before { job.perform(nil, {}) }

        it "does not flip the setting" do
          expect(Setting.work_packages_identifier).not_to eq(Setting::WorkPackageIdentifier::SEMANTIC)
        end

        it "re-enqueues a BackfillProjectJob for the problematic project" do
          enqueued_ids = GoodJob::Job
            .where(job_class: ProjectIdentifiers::BackfillProjectJob.name)
            .map { |j| j.serialized_params.dig("arguments", 0) }
          expect(enqueued_ids).to include(project.id)
        end
      end

      context "when remaining items exist but MAX_ITERATIONS has been reached" do
        let!(:project) { create(:project) }
        let!(:wp)      { create(:work_package, project:) }

        it "raises and does not flip the setting" do
          expect { job.perform(nil, { iteration: described_class::MAX_ITERATIONS }) }
            .to raise_error(RuntimeError, /max iterations/)
          expect(Setting.work_packages_identifier).not_to eq(Setting::WorkPackageIdentifier::SEMANTIC)
        end

        it "logs an error before raising" do
          allow(Rails.logger).to receive(:error)
          expect { job.perform(nil, { iteration: described_class::MAX_ITERATIONS }) }
            .to raise_error(RuntimeError)
          expect(Rails.logger).to have_received(:error).with(a_string_including("max iterations"))
        end
      end

      context "when remaining items exist and iteration is below MAX_ITERATIONS" do
        let!(:project) { create(:project) }
        let!(:wp)      { create(:work_package, project:) }

        it "increments iteration by 1 in on_success_params for the next batch" do
          allow(GoodJob::Batch).to receive(:enqueue).and_call_original
          job.perform(nil, { iteration: 3 })
          expect(GoodJob::Batch).to have_received(:enqueue)
            .with(hash_including(on_success_params: hash_including(iteration: 4)))
        end
      end
    end
  end
end
