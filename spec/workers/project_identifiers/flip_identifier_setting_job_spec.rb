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

RSpec.describe ProjectIdentifiers::FlipIdentifierSettingJob do
  subject(:job) { described_class.new }

  # Simulate classic mode — WP after_create hook does not auto-assign sequence numbers.
  before do
    allow(Setting::WorkPackageIdentifier).to receive_messages(semantic?: false, classic?: true)
  end

  describe "#perform" do
    context "when no projects or work packages remain unprocessed" do
      it "flips the setting to semantic" do
        job.perform(nil, {})
        expect(Setting.work_packages_identifier).to eq(Setting::WorkPackageIdentifier::SEMANTIC)
      end
    end

    context "when work packages with sequence_number: nil remain",
            with_good_job_batches: [
              described_class,
              ProjectIdentifiers::BackfillProjectJob
            ] do
      let!(:project) { create(:project) }
      let!(:wp) { create(:work_package, project:) }

      before { job.perform(nil, {}) }

      it "does not flip the setting" do
        expect(Setting.work_packages_identifier).not_to eq(Setting::WorkPackageIdentifier::SEMANTIC)
      end

      it "enqueues a BackfillProjectJob for the project with unprocessed work packages" do
        enqueued_ids = GoodJob::Job
          .where(job_class: ProjectIdentifiers::BackfillProjectJob.name)
          .map { |j| j.serialized_params.dig("arguments", 0) }
        expect(enqueued_ids).to include(project.id)
      end
    end

    context "when a project has a problematic identifier",
            with_good_job_batches: [
              described_class,
              ProjectIdentifiers::BackfillProjectJob
            ] do
      let!(:project) { create(:project).tap { |p| p.update_columns(identifier: "has-dashes") } }
      let!(:wp) { create(:work_package, project:) }

      before { job.perform(nil, {}) }

      it "does not flip the setting" do
        expect(Setting.work_packages_identifier).not_to eq(Setting::WorkPackageIdentifier::SEMANTIC)
      end

      it "enqueues a BackfillProjectJob for the problematic project" do
        enqueued_ids = GoodJob::Job
          .where(job_class: ProjectIdentifiers::BackfillProjectJob.name)
          .map { |j| j.serialized_params.dig("arguments", 0) }
        expect(enqueued_ids).to include(project.id)
      end
    end

    context "when remaining items exist but MAX_ITERATIONS has been reached" do
      let!(:project) { create(:project) }
      let!(:wp) { create(:work_package, project:) }

      it "does not flip the setting" do
        job.perform(nil, { "iteration" => described_class::MAX_ITERATIONS })
        expect(Setting.work_packages_identifier).not_to eq(Setting::WorkPackageIdentifier::SEMANTIC)
      end

      it "logs an error" do
        allow(Rails.logger).to receive(:error)
        job.perform(nil, { "iteration" => described_class::MAX_ITERATIONS })
        expect(Rails.logger).to have_received(:error).with(a_string_including("max iterations"))
      end
    end
  end
end
