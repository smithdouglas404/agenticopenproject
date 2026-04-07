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

RSpec.describe ProjectIdentifiers::ConvertInstanceToSemanticIds,
               with_good_job_batches: [
                 ProjectIdentifiers::ConvertInstanceToSemanticIds,
                 ProjectIdentifiers::BackfillProjectJob
               ] do
  subject(:job) { described_class.new }

  # Simulate legacy (classic) mode — the job runs before flipping the switch.
  # In this mode the WP after_create hook does not auto-assign sequence numbers,
  # so WPs start with sequence_number: nil and identifier: nil.
  before do
    allow(Setting::WorkPackageIdentifier).to receive_messages(semantic?: false, classic?: true)
  end

  describe "#perform" do
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
  end
end
