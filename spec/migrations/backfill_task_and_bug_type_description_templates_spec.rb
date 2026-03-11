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

require "spec_helper"
require Rails.root.join("db/migrate/20260311182000_backfill_task_and_bug_type_description_templates.rb")

RSpec.describe BackfillTaskAndBugTypeDescriptionTemplates, type: :model do
  subject(:migrate!) { ActiveRecord::Migration.suppress_messages { described_class.migrate(:up) } }

  let!(:task_type) { create(:type_task, description: task_description) }
  let!(:bug_type) { create(:type_bug, description: bug_description) }
  let!(:feature_type) { create(:type_feature, description: feature_description) }

  context "when bug and task descriptions are blank" do
    let(:task_description) { "" }
    let(:bug_description) { "" }
    let(:feature_description) { "Existing feature template" }

    it "backfills bug and task descriptions but does not touch other types" do
      migrate!

      expect(task_type.reload.description).to eq(described_class::TASK_TEMPLATE)
      expect(bug_type.reload.description).to eq(described_class::BUG_TEMPLATE)
      expect(feature_type.reload.description).to eq("Existing feature template")
    end
  end

  context "when bug and task descriptions already exist" do
    let(:task_description) { "Task template from admin" }
    let(:bug_description) { "Bug template from admin" }
    let(:feature_description) { "" }

    it "does not overwrite existing custom templates" do
      migrate!

      expect(task_type.reload.description).to eq("Task template from admin")
      expect(bug_type.reload.description).to eq("Bug template from admin")
      expect(feature_type.reload.description).to eq("")
    end
  end
end
