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

RSpec.describe ProjectIdentifiers::FinishRevertingInstanceToClassicIdsJob do
  subject(:job) { described_class.new }

  before do
    allow(Setting::WorkPackageIdentifier).to receive(:enable_classic!)
  end

  describe "#perform" do
    context "when called with a batch containing task_id in properties" do
      let(:task) { LongRunningTask.create!(task_type: :semantic_id_reversion).tap(&:start!) }
      let(:batch) { instance_double(GoodJob::Batch, properties: { "task_id" => task.id }) }

      it "marks the task as complete" do
        job.perform(batch, { event: :success })
        expect(task.reload.status).to eq("complete")
      end
    end

    context "when called without a batch (direct dispatch)" do
      it "does not raise" do
        expect { job.perform }.not_to raise_error
      end
    end

    it "enables classic identifiers" do
      job.perform
      expect(Setting::WorkPackageIdentifier).to have_received(:enable_classic!)
    end
  end
end
