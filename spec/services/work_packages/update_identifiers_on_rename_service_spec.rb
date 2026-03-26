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

RSpec.describe WorkPackages::UpdateIdentifiersOnRenameService do
  subject(:service) { described_class.new(project:) }

  context "when in alphanumeric mode",
          with_settings: { work_packages_identifier: Setting::WorkPackageIdentifier::ALPHANUMERIC } do
    let(:project) { create(:project, identifier: "SCO") }

    let!(:wp1) do
      wp = create(:work_package, project:)
      wp.update_columns(sequence_number: 1, identifier: "SC-1")
      wp
    end

    let!(:wp2) do
      wp = create(:work_package, project:)
      wp.update_columns(sequence_number: 2, identifier: "SC-2")
      wp
    end

    it "updates all work package identifiers to use the new project prefix" do
      service.call

      expect(wp1.reload.identifier).to eq("SCO-1")
      expect(wp2.reload.identifier).to eq("SCO-2")
    end

    it "preserves sequence numbers unchanged" do
      service.call

      expect(wp1.reload.sequence_number).to eq(1)
      expect(wp2.reload.sequence_number).to eq(2)
    end

    it "does not write any FriendlyId slugs for work packages" do
      expect { service.call }
        .not_to change { FriendlyId::Slug.where(sluggable_type: "WorkPackage").count }
    end

    it "makes old identifiers resolvable via structural resolution" do
      # Record the old project identifier in FriendlyId slug history (as Projects::SetAttributesService does)
      FriendlyId::Slug.create!(slug: "SC", sluggable: project, sluggable_type: "Project")

      service.call

      # Old prefix resolves via Project FriendlyId history + structural lookup
      expect(WorkPackage.find("SC-1")).to eq(wp1)
      expect(WorkPackage.find("SCO-1")).to eq(wp1)
    end
  end

  context "when in numeric mode",
          with_settings: { work_packages_identifier: Setting::WorkPackageIdentifier::NUMERIC } do
    let(:project) { create(:project, identifier: "some-project") }

    let!(:wp) { create(:work_package, project:) }

    it "is a no-op" do
      expect { service.call }.not_to change { wp.reload.identifier }
    end
  end

  context "when project has no work packages with identifiers",
          with_settings: { work_packages_identifier: Setting::WorkPackageIdentifier::ALPHANUMERIC } do
    let(:project) { create(:project, identifier: "EMPTY") }

    it "completes without error" do
      expect { service.call }.not_to raise_error
    end
  end
end
