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

RSpec.describe Backlogs::Sprints::GoalFormModel do
  describe ".for" do
    let(:project) { create(:project) }
    let(:sprint) { create(:sprint, project:) }

    it "wraps the contextual goal" do
      goal = create(:sprint_goal, sprint:, project:, text: "Ship MVP")

      form_model = described_class.for(sprint:, project:)

      expect(form_model).to have_attributes(
        id: goal.id,
        project_id: project.id,
        text: "Ship MVP"
      )
    end

    it "builds a blank command for a project without a goal" do
      form_model = described_class.for(sprint:, project:)

      expect(form_model).to have_attributes(
        id: nil,
        project_id: project.id,
        text: nil
      )
    end
  end

  describe "#to_nested_attributes" do
    it "returns attributes for a new goal" do
      form_model = described_class.new(project_id: 12, text: "Ship MVP")

      expect(form_model.to_nested_attributes).to eq(project_id: 12, text: "Ship MVP")
    end

    it "does not mark a new blank goal for destruction" do
      form_model = described_class.new(project_id: 12, text: "")

      expect(form_model.to_nested_attributes).to eq(project_id: 12, text: "")
    end

    it "returns attributes for an existing goal" do
      form_model = described_class.new(id: 5, project_id: 12, text: "Ship MVP")

      expect(form_model.to_nested_attributes).to eq(id: 5, project_id: 12, text: "Ship MVP")
    end

    it "marks an existing blank goal for destruction" do
      form_model = described_class.new(id: 5, project_id: 12, text: "")

      expect(form_model.to_nested_attributes).to eq(id: 5, project_id: 12, text: "", _destroy: "1")
    end
  end
end
