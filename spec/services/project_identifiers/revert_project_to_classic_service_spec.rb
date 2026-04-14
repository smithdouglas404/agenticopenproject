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

RSpec.describe ProjectIdentifiers::RevertProjectToClassicService do
  describe "#call" do
    context "when the project has work packages with semantic data" do
      let!(:project) do
        create(:project).tap { |p| p.update_columns(identifier: "MYAPP", wp_sequence_counter: 5) }
      end
      let!(:wp1) { create(:work_package, project:).tap { |w| w.update_columns(sequence_number: 1, identifier: "MYAPP-1") } }
      let!(:wp2) { create(:work_package, project:).tap { |w| w.update_columns(sequence_number: 2, identifier: "MYAPP-2") } }

      before { described_class.new(project).call }

      it "clears sequence_number on all work packages" do
        expect(wp1.reload.sequence_number).to be_nil
        expect(wp2.reload.sequence_number).to be_nil
      end

      it "clears identifier on all work packages" do
        expect(wp1.reload.identifier).to be_nil
        expect(wp2.reload.identifier).to be_nil
      end

      it "resets the wp_sequence_counter to 0" do
        expect(project.reload.wp_sequence_counter).to eq(0)
      end
    end

    context "when the project has WorkPackageSemanticAlias rows" do
      let!(:project) do
        create(:project).tap { |p| p.update_columns(identifier: "MYAPP", wp_sequence_counter: 1) }
      end
      let!(:wp) { create(:work_package, project:).tap { |w| w.update_columns(sequence_number: 1, identifier: "MYAPP-1") } }
      let!(:other_project) { create(:project).tap { |p| p.update_columns(identifier: "OTHER") } }
      let!(:other_wp) { create(:work_package, project: other_project).tap { |w| w.update_columns(sequence_number: 1, identifier: "OTHER-1") } }

      before do
        WorkPackageSemanticAlias.create!(identifier: "MYAPP-1", work_package: wp)
        WorkPackageSemanticAlias.create!(identifier: "OLD-1", work_package: wp)
        WorkPackageSemanticAlias.create!(identifier: "OTHER-1", work_package: other_wp)
        described_class.new(project).call
      end

      it "deletes alias rows for work packages in the project" do
        expect(WorkPackageSemanticAlias.where(work_package: wp)).not_to exist
      end

      it "leaves alias rows for work packages in other projects untouched" do
        expect(WorkPackageSemanticAlias.where(work_package: other_wp)).to exist
      end
    end

    context "when the project has a classic identifier in FriendlyId history" do
      let!(:project) do
        create(:project).tap do |p|
          p.update_columns(identifier: "MYAPP", wp_sequence_counter: 0)
          FriendlyId::Slug.create!(sluggable: p, slug: "my-app")
        end
      end

      before { described_class.new(project).call }

      it "restores the classic identifier" do
        expect(project.reload.identifier).to eq("my-app")
      end
    end

    context "when the project has multiple slugs in FriendlyId history" do
      let!(:project) do
        create(:project).tap do |p|
          p.update_columns(identifier: "MYAPP", wp_sequence_counter: 0)
          FriendlyId::Slug.create!(sluggable: p, slug: "old-name", created_at: 2.hours.ago)
          FriendlyId::Slug.create!(sluggable: p, slug: "newer-name", created_at: 1.hour.ago)
        end
      end

      before { described_class.new(project).call }

      it "restores the most recent classic slug" do
        expect(project.reload.identifier).to eq("newer-name")
      end
    end

    context "when the project has only semantic identifiers in FriendlyId history" do
      let!(:project) do
        create(:project).tap do |p|
          p.update_columns(identifier: "MYAPP", wp_sequence_counter: 3)
          FriendlyId::Slug.where(sluggable: p).delete_all
          FriendlyId::Slug.create!(sluggable: p, slug: "MYAPP")
        end
      end

      before { described_class.new(project).call }

      it "leaves the identifier unchanged" do
        expect(project.reload.identifier).to eq("MYAPP")
      end
    end
  end
end
