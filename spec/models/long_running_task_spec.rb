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

RSpec.describe LongRunningTask do
  let(:task) { described_class.create!(task_type: :semantic_id_conversion) }

  describe "task_type" do
    it "is required" do
      expect { described_class.create!(status: :pending) }.to raise_error(ActiveRecord::RecordInvalid, /Task type/)
    end
  end

  describe "created_by" do
    it "is inferred from User.current if not set" do
      user = create(:user)
      allow(User).to receive(:current).and_return(user)

      expect(described_class.create!(task_type: :semantic_id_conversion).created_by).to eq(user)
    end

    it "respects an explicitly provided value" do
      user = create(:user)
      other = create(:user)
      allow(User).to receive(:current).and_return(user)

      task = described_class.create!(task_type: :semantic_id_conversion, created_by: other)
      expect(task.created_by).to eq(other)
    end

    it "is nil when User.current is nil" do
      allow(User).to receive(:current).and_return(nil)

      expect(described_class.create!(task_type: :semantic_id_conversion).created_by).to be_nil
    end
  end

  describe "description" do
    it "can be set on creation" do
      task = described_class.create!(task_type: :semantic_id_conversion, description: "my task")
      expect(task.reload.description).to eq("my task")
    end
  end

  describe "state transitions" do
    describe "#start!" do
      it "transitions from pending to processing" do
        expect { task.start! }.to change { task.reload.status }
          .from("pending").to("processing")
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
          .from("processing").to("complete")
      end

      it "sets completed_at" do
        expect { task.complete! }.to change { task.reload.completed_at }.from(nil)
      end

      it "raises when called from pending" do
        pending_task = described_class.create!(task_type: :semantic_id_conversion)
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
          .from("processing").to("failed")
      end

      it "sets failed_at" do
        expect { task.fail! }.to change { task.reload.failed_at }.from(nil)
      end

      it "raises when called from pending" do
        pending_task = described_class.create!(task_type: :semantic_id_conversion)
        expect { pending_task.fail! }.to raise_error(ArgumentError, /pending → failed/)
      end

      it "raises when called after complete" do
        task.complete!
        expect { task.fail! }.to raise_error(ArgumentError)
      end
    end

    describe "#abort!" do
      it "transitions from pending to aborted" do
        expect { task.abort! }.to change { task.reload.status }
          .from("pending").to("aborted")
      end

      it "transitions from processing to aborted" do
        task.start!
        expect { task.abort! }.to change { task.reload.status }
          .from("processing").to("aborted")
      end

      it "sets aborted_at" do
        expect { task.abort! }.to change { task.reload.aborted_at }.from(nil)
      end

      it "raises when called after complete" do
        task.start!
        task.complete!
        expect { task.abort! }.to raise_error(ArgumentError, /complete → aborted/)
      end

      it "raises when called after failed" do
        task.start!
        task.fail!
        expect { task.abort! }.to raise_error(ArgumentError, /failed → aborted/)
      end
    end
  end
end
