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

RSpec.describe WorkPackages::ActivitiesTab::Paginator do
  shared_let(:user) { create(:admin) }
  shared_let(:project) { create(:project) }
  shared_let(:work_package) { create(:work_package, :created_in_past, project:, author: user, created_at: 4.days.ago) }

  let(:params) { {} }
  let(:paginator) { described_class.new(work_package, params) }

  before do
    allow(User).to receive(:current).and_return(user)
  end

  describe "#call" do
    context "with no additional journals" do
      let(:work_package) { create(:work_package, project:, author: user) }

      it "returns paginated results with the initial journal" do
        pagy, records = paginator.call

        expect(pagy).to be_a(Pagy)
        expect(pagy.page).to eq(1)
        expect(pagy.count).to eq(1)
        expect(records).to have_attributes(size: 1)
        expect(records.first).to be_a(API::V3::Activities::ActivityEagerLoadingWrapper)
      end
    end

    context "with multiple journals" do
      3.times do |i|
        let!(:"journal_#{i + 1}") do
          create(:work_package_journal, user:, notes: "Comment #{i + 1}", journable: work_package, version: i + 2)
        end
      end

      context "when user preference is set to asc sorting" do
        before do
          user.pref.update!(comments_sorting: :asc)
        end

        it "returns journals reversed (oldest first)" do
          _pagy, records = paginator.call

          expect(records.map(&:notes)).to eq(["", journal_1.notes, journal_2.notes, journal_3.notes])
        end
      end

      context "when user preference is set to desc sorting" do
        before do
          user.pref.update!(comments_sorting: :desc)
        end

        it "returns journals in DESC order (newest first)" do
          _pagy, records = paginator.call

          expect(records.map(&:notes)).to eq([journal_3.notes, journal_2.notes, journal_1.notes, ""])
        end
      end
    end

    context "with changesets" do
      let(:repository) { create(:repository_subversion, project:) }

      2.times do |i|
        let!(:"changeset_#{i + 1}") do
          create(:changeset,
                 repository:,
                 committed_on: (2 - i).days.ago, # yesterday and today
                 revision: "rev#{i + 1}")
        end
      end

      before do
        work_package.changesets << [changeset_1, changeset_2]
      end

      it "includes changesets in the sorted results" do
        _pagy, records = paginator.call

        expect(records.size).to eq(3) # 1 initial journal + 2 changesets
        expect(records).to include(changeset_1, changeset_2)
      end

      it "sorts changesets along with journals by timestamp" do
        user.pref.update!(comments_sorting: :desc)
        journal = create(:work_package_journal,
                         user:,
                         notes: "Comment between changesets",
                         journable: work_package,
                         version: work_package.journals.last.version + 1,
                         created_at: 1.5.days.ago)

        _pagy, records = paginator.call
        expect(records).to eq([changeset_2, journal, changeset_1, work_package.journals.first])
      end
    end

    context "with pagination" do
      # Create enough journals to span multiple pages (default limit is 20)
      25.times do |i|
        let!(:"journal_#{i + 1}") do
          create(:work_package_journal, user:, notes: "Comment #{i + 1}", journable: work_package, version: i + 2)
        end
      end

      it "returns the first page with default limit" do
        pagy, records = paginator.call

        expect(pagy.page).to eq(1)
        expect(pagy.count).to eq(26) # 25 journals + 1 initial
        expect(pagy.pages).to eq(2)
        expect(records.size).to eq(20) # Default Pagy limit
      end

      it "returns the second page when requested" do
        params[:page] = 2
        pagy, records = paginator.call

        expect(pagy.page).to eq(2)
        expect(records.size).to eq(6) # Remaining items
      end

      context "with anchor to target journal" do
        context "with comment anchor" do
          it "returns the page containing the target journal" do
            params[:anchor] = "comment-#{journal_1.id}"
            pagy, records = paginator.call

            # journal_1 is old, so it should be on page 2
            expect(pagy.page).to eq(2)
            expect(records.map(&:id)).to include(journal_1.id)
          end

          it "handles invalid anchor format gracefully" do
            params[:anchor] = "invalid-anchor"
            pagy, _records = paginator.call

            expect(pagy.page).to eq(1)
          end

          it "falls back to page 1 if journal not found" do
            params[:anchor] = "comment-999999"
            pagy, _records = paginator.call

            expect(pagy.page).to eq(1)
          end
        end

        context "with activity anchor" do
          it "returns the page containing the target activity by sequence_version" do
            params[:anchor] = "activity-2"
            pagy, records = paginator.call

            # activity-2 corresponds to journal with sequence_version 2
            # which should be journal_1
            expect(pagy.page).to eq(2)
            wrapped_journal = records.find { it.is_a?(API::V3::Activities::ActivityEagerLoadingWrapper) && it.id == journal_1.id }
            expect(wrapped_journal.sequence_version).to eq(2)
          end

          it "handles activity anchor for initial journal" do
            params[:anchor] = "activity-1"
            _pagy, records = paginator.call

            # activity-1 should be on the last page (oldest)
            expect(records.any? { it.respond_to?(:sequence_version) && it.sequence_version == 1 }).to be(true)
          end
        end
      end
    end

    context "with internal comments filtering" do
      let!(:internal_journal) do
        create(:work_package_journal,
               user:,
               notes: "Internal comment",
               journable: work_package,
               internal: true,
               version: 2)
      end
      let!(:public_journal) do
        create(:work_package_journal,
               user:,
               notes: "Public comment",
               journable: work_package,
               internal: false,
               version: 3)
      end

      before do
        work_package.project.enabled_internal_comments = true
        work_package.project.save!
      end

      context "when user can see internal comments" do
        it "includes internal journals" do
          _pagy, records = paginator.call

          journal_notes = records.map(&:notes)
          expect(journal_notes).to include("Internal comment", "Public comment")
        end
      end

      context "when user cannot see internal comments" do
        let(:member_role) { create(:project_role, permissions: %i[view_work_packages]) }
        let(:member_user) { create(:user, member_with_roles: { project => member_role }) }

        before do
          allow(User).to receive(:current).and_return(member_user)
        end

        it "excludes internal journals" do
          _pagy, records = described_class.new(work_package, params).call

          journal_notes = records.map(&:notes)
          expect(journal_notes).not_to include("Internal comment")
          expect(journal_notes).to include("Public comment")
        end
      end
    end
  end
end
