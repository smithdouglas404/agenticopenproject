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

RSpec.describe Projects::UpdateService, "integration", type: :model do
  let(:user) do
    create(:user, member_with_roles: { project => role })
  end
  let(:role) do
    create(:project_role,
           permissions:)
  end
  let(:permissions) do
    %i(edit_project view_project_attributes edit_project_attributes)
  end

  let!(:project) do
    create(:project,
           custom_field.attribute_name => 1,
           status_code:,
           status_explanation:)
  end
  let(:instance) { described_class.new(user:, model: project) }
  let(:custom_field) { create(:integer_project_custom_field) }
  let(:status_code) { nil }
  let(:status_explanation) { nil }
  let(:attributes) { {} }
  let(:service_result) do
    instance
      .call(attributes)
  end

  describe "#call" do
    context "if only a custom field is updated" do
      let(:attributes) do
        { custom_field.attribute_name => 8 }
      end

      it "touches the project after saving" do
        former_updated_at = Project.pluck(:updated_at).first

        service_result

        later_updated_at = Project.pluck(:updated_at).first

        expect(former_updated_at)
          .not_to eql later_updated_at
      end
    end

    context "if a new custom field gets a value assigned" do
      let(:custom_field2) { create(:text_project_custom_field) }

      let(:attributes) do
        { custom_field2.attribute_name => "some text" }
      end

      it "touches the project after saving" do
        former_updated_at = Project.pluck(:updated_at).first

        service_result

        later_updated_at = Project.pluck(:updated_at).first

        expect(former_updated_at)
          .not_to eql later_updated_at
      end
    end

    context "when saving the status as well as the parent" do
      let(:parent_project) { create(:project, members: { user => parent_role }) }
      let(:parent_role) { create(:project_role, permissions: %i(add_subprojects)) }
      let(:status_code) { "on_track" }
      let(:status_explanation) { "some explanation" }
      let(:attributes) do
        {
          parent_id: parent_project.id,
          status_code: "off_track"
        }
      end

      it "updates both the status as well as the parent" do
        service_result

        expect(project.parent)
          .to eql parent_project

        expect(project)
          .to be_off_track
      end
    end
  end

  context "with the seeded demo project" do
    let(:demo_project) { create(:project, name: "Demo project", identifier: "demo-project", public: true) }
    let(:instance) { described_class.new(user:, model: demo_project) }
    let(:attributes) do
      { public: false }
    end

    it "saves in a Setting that the demo project was made private (regression #52826)" do
      # Make the demo project private
      service_result
      expect(demo_project.public).to be(false)

      # Demo project is not available for the onboarding tour any more
      expect(Setting.demo_projects_available).to be(false)
    end
  end

  describe "work package identifier update on project rename" do
    let(:permissions) { %i[edit_project view_project_attributes edit_project_attributes view_work_packages] }

    context "when in alphanumeric mode",
            with_settings: { work_packages_identifier: Setting::WorkPackageIdentifier::ALPHANUMERIC } do
      let!(:project) { create(:project, identifier: "SC") }

      let!(:wp1) do
        wp = create(:work_package, project:)
        wp.update_columns(sequence_number: 1, identifier: "SC-1")
        HistoricalWorkPackageIdentifier.create!(project:, work_package: wp, sequence_number: 1)
        wp
      end

      let!(:wp2) do
        wp = create(:work_package, project:)
        wp.update_columns(sequence_number: 2, identifier: "SC-2")
        HistoricalWorkPackageIdentifier.create!(project:, work_package: wp, sequence_number: 2)
        wp
      end

      let(:attributes) { { identifier: "SCO" } }

      it "updates all work package identifiers to use the new project prefix" do
        expect(service_result).to be_success

        expect(wp1.reload.identifier).to eq("SCO-1")
        expect(wp2.reload.identifier).to eq("SCO-2")
      end

      it "preserves sequence numbers unchanged" do
        service_result

        expect(wp1.reload.sequence_number).to eq(1)
        expect(wp2.reload.sequence_number).to eq(2)
      end

      it "records old identifiers in FriendlyId slug history" do
        service_result

        expect(FriendlyId::Slug.where(slug: "SC-1", sluggable_type: "WorkPackage")).to exist
        expect(FriendlyId::Slug.where(slug: "SC-2", sluggable_type: "WorkPackage")).to exist
      end

      it "makes old identifiers resolvable via FriendlyId" do
        service_result

        expect(WorkPackage.friendly.find("SC-1")).to eq(wp1)
        expect(WorkPackage.friendly.find("SCO-1")).to eq(wp1)
      end

      it "does not modify historical_work_package_identifiers records" do
        expect { service_result }.not_to change {
          HistoricalWorkPackageIdentifier.where(project:).pluck(:sequence_number).sort
        }
      end
    end

    context "when in numeric mode",
            with_settings: { work_packages_identifier: Setting::WorkPackageIdentifier::NUMERIC } do
      let!(:project) { create(:project, identifier: "some-project") }
      let(:attributes) { { identifier: "renamed-project" } }

      let!(:wp) do
        create(:work_package, project:)
      end

      it "does not touch work package identifiers" do
        expect(service_result).to be_success
        expect(wp.reload.identifier).to be_nil
      end
    end

    context "when project has no work packages with identifiers",
            with_settings: { work_packages_identifier: Setting::WorkPackageIdentifier::ALPHANUMERIC } do
      let!(:project) { create(:project, identifier: "EMPTY") }
      let(:attributes) { { identifier: "RENAMED" } }

      it "completes without error" do
        expect(service_result).to be_success
      end
    end
  end
end
