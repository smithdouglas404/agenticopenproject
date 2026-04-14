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

RSpec.describe BackgroundTask do
  let(:task) { described_class.create!(task_type: described_class::SEMANTIC_ID_CONVERSION) }

  describe "state transitions" do
    describe "#start!" do
      it "transitions from pending to processing" do
        expect { task.start! }.to change { task.reload.status }
          .from(described_class::PENDING).to(described_class::PROCESSING)
      end

      it "sets started_at" do
        expect { task.start! }.to change { task.reload.started_at }.from(nil)
      end

      it "raises when called from processing" do
        task.start!
        expect { task.start! }.to raise_error(ArgumentError, /processing → processing/)
      end

      it "raises when called from complete" do
        task.start!
        task.complete!
        expect { task.start! }.to raise_error(ArgumentError)
      end
    end

    describe "#complete!" do
      before { task.start! }

      it "transitions from processing to complete" do
        expect { task.complete! }.to change { task.reload.status }
          .from(described_class::PROCESSING).to(described_class::COMPLETE)
      end

      it "sets completed_at" do
        expect { task.complete! }.to change { task.reload.completed_at }.from(nil)
      end

      it "raises when called from pending" do
        pending_task = described_class.create!(task_type: described_class::SEMANTIC_ID_CONVERSION)
        expect { pending_task.complete! }.to raise_error(ArgumentError, /pending → complete/)
      end

      it "raises when called again from complete" do
        task.complete!
        expect { task.complete! }.to raise_error(ArgumentError)
      end
    end

    describe "#fail!" do
      before { task.start! }

      it "transitions from processing to failed" do
        expect { task.fail! }.to change { task.reload.status }
          .from(described_class::PROCESSING).to(described_class::FAILED)
      end

      it "sets failed_at" do
        expect { task.fail! }.to change { task.reload.failed_at }.from(nil)
      end

      it "raises when called from pending" do
        pending_task = described_class.create!(task_type: described_class::SEMANTIC_ID_CONVERSION)
        expect { pending_task.fail! }.to raise_error(ArgumentError, /pending → failed/)
      end

      it "raises when called after complete" do
        task.complete!
        expect { task.fail! }.to raise_error(ArgumentError)
      end
    end
  end
end
