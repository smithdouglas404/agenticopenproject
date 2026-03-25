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

RSpec.describe OpenProject::Backlogs::SprintFilter do
  let(:scope_class) do
    Class.new do
      def for_project(_project); end

      def pluck(*_args); end
    end
  end
  let(:sprint) { build_stubbed(:agile_sprint) }

  it_behaves_like "basic query filter" do
    let(:type) { :list_optional }
    let(:class_key) { :sprint_id }
    let(:values) { [sprint.id.to_s] }
    let(:model) { WorkPackage }

    let(:visible_scope) { instance_double(scope_class) }
    let(:scope) { instance_double(scope_class) }

    before do
      allow(project).to receive(:module_enabled?).with(:backlogs).and_return(true)
      allow(OpenProject::FeatureDecisions).to receive(:scrum_projects_active?).and_return(true)
      allow(Agile::Sprint)
        .to receive(:visible)
        .and_return(visible_scope)

      if project
        allow(visible_scope)
          .to receive(:for_project)
          .with(project)
          .and_return(scope)
      end

      allow(scope).to receive(:pluck).with(:id, :id).and_return([[sprint.id, sprint.id]])
      allow(visible_scope).to receive(:pluck).with(:id, :id).and_return([[sprint.id, sprint.id]])
    end

    describe "#available?" do
      context "when scrum projects is active and backlogs is enabled" do
        it "is true" do
          expect(instance).to be_available
        end
      end

      context "when scrum projects is inactive" do
        before do
          allow(OpenProject::FeatureDecisions).to receive(:scrum_projects_active?).and_return(false)
        end

        it "is false" do
          expect(instance).not_to be_available
        end
      end

      context "when backlogs is not enabled" do
        before do
          allow(project).to receive(:module_enabled?).with(:backlogs).and_return(false)
        end

        it "is false" do
          expect(instance).not_to be_available
        end
      end
    end

    describe "#ar_object_filter?" do
      it "is true" do
        expect(instance).to be_ar_object_filter
      end
    end

    describe "dependency representer" do
      it "maps to the sprint dependency representer" do
        dependency = API::V3::Queries::Schemas::FilterDependencyRepresenterFactory.create(instance,
                                                                                          Queries::Operators::Equals)

        expect(dependency).to be_a(API::V3::Queries::Schemas::SprintFilterDependencyRepresenter)
      end
    end

    describe "#value_objects" do
      let(:sprint1) { build_stubbed(:agile_sprint) }
      let(:sprint2) { build_stubbed(:agile_sprint) }

      before do
        allow(visible_scope)
          .to receive(:for_project)
          .with(project)
          .and_return([sprint1, sprint2])

        instance.values = [sprint1.id.to_s]
      end

      it "returns an array of sprints" do
        expect(instance.value_objects)
          .to contain_exactly(sprint1)
      end
    end
  end
end
