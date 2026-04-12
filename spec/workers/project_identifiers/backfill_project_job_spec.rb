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

RSpec.describe ProjectIdentifiers::BackfillProjectJob do
  subject(:job) { described_class.new }

  # Simulate legacy (classic) mode so WPs are created without sequence numbers.
  before do
    allow(Setting::WorkPackageIdentifier).to receive_messages(semantic?: false, classic?: true)
  end

  describe "#perform" do
    context "when the project has a prior valid semantic identifier in FriendlyId history" do
      let!(:project) do
        create(:project).tap do |p|
          p.update_columns(identifier: "my-app", wp_sequence_counter: 0)
          FriendlyId::Slug.create!(sluggable: p, slug: "MYAPP")
        end
      end

      before { job.perform(project.id) }

      it "restores the prior semantic identifier instead of generating a new one" do
        expect(project.reload.identifier).to eq("MYAPP")
      end
    end

    context "when the prior semantic identifier is already taken by another project" do
      let!(:other)   { create(:project).tap { |p| p.update_columns(identifier: "MYAPP") } }
      let!(:project) do
        create(:project).tap do |p|
          p.update_columns(identifier: "my-app", wp_sequence_counter: 0)
          FriendlyId::Slug.create!(sluggable: p, slug: "MYAPP")
        end
      end

      before { job.perform(project.id) }

      it "falls back to a freshly generated semantic identifier" do
        identifier = project.reload.identifier
        expect(identifier).not_to eq("my-app")
        expect(identifier).not_to eq("MYAPP")
        expect(identifier).to match(/\A[A-Z][A-Z0-9_]{1,9}\z/)
      end
    end

    context "when the project has a problematic identifier" do
      let!(:project) { create(:project, name: "My Project") }
      let!(:wp)      { create(:work_package, project:) }

      before { job.perform(project.id) }

      it "renames the project to a valid semantic identifier" do
        expect(project.reload.identifier).to match(/\A[A-Z][A-Z0-9_]{1,9}\z/)
      end

      it "backfills WPs using the new identifier" do
        expect(wp.reload.identifier).to eq("#{project.reload.identifier}-1")
      end
    end

    context "when the project already has a valid identifier" do
      let!(:project) do
        create(:project).tap { |p| p.update_columns(identifier: "MYAPP", wp_sequence_counter: 0) }
      end
      let!(:wp) { create(:work_package, project:) }

      before { job.perform(project.id) }

      it "leaves the identifier unchanged" do
        expect(project.reload.identifier).to eq("MYAPP")
      end
    end

    context "when a project has work packages without sequence numbers" do
      let!(:project) do
        create(:project).tap { |p| p.update_columns(identifier: "MYAPP", wp_sequence_counter: 0) }
      end
      let!(:wp1) { create(:work_package, project:) }
      let!(:wp2) { create(:work_package, project:) }

      before { job.perform(project.id) }

      it "assigns sequence numbers in id (oldest-first) order" do
        expect(wp1.reload.sequence_number).to eq(1)
        expect(wp2.reload.sequence_number).to eq(2)
      end

      it "sets identifier on each WP using the project identifier" do
        expect(wp1.reload.identifier).to eq("MYAPP-1")
        expect(wp2.reload.identifier).to eq("MYAPP-2")
      end
    end

    context "when seeding the alias table" do
      let!(:project) do
        create(:project).tap { |p| p.update_columns(identifier: "CURR", wp_sequence_counter: 0) }
      end
      let!(:wp) { create(:work_package, project:) }

      before do
        # Simulate historical identifier by seeding FriendlyId slugs directly,
        # which is what semantic_identifier_aliases reads from.
        FriendlyId::Slug.where(sluggable: project).delete_all
        FriendlyId::Slug.create!(sluggable: project, slug: "OLD")
        FriendlyId::Slug.create!(sluggable: project, slug: "CURR")
        job.perform(project.id)
      end

      it "inserts alias rows for all historical prefixes" do
        seq = wp.reload.sequence_number
        expect(WorkPackageSemanticAlias.where(work_package_id: wp.id).pluck(:identifier))
          .to contain_exactly("OLD-#{seq}", "CURR-#{seq}")
      end
    end
  end
end
