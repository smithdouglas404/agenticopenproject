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
require_relative "../markdown/expected_markdown"

RSpec.describe OpenProject::TextFormatting::Filters::MentionFilter do
  include_context "expected markdown modules"

  describe "work package mention" do
    let(:role) { create(:project_role, permissions: %i[view_work_packages]) }
    let(:author) { create(:user, member_with_roles: { project => role }) }

    before { allow(User).to receive(:current).and_return(author) }

    # Defaults produce the numeric form (`data-id` = primary key,
    # `data-text` = `#N`).
    def mention_tag(work_package, sep: "#", data_id: nil, data_text: nil)
      did = data_id || work_package.id
      text = data_text || "#{sep}#{work_package.id}"
      <<~HTML
        <mention class="mention"
                 data-id="#{did}"
                 data-type="work_package"
                 data-text="#{text}">#{text}</mention>
      HTML
    end

    context "as plain link in classic mode",
            with_flag: { semantic_work_package_ids: false },
            with_settings: { work_packages_identifier: "classic" } do
      let(:project) { create(:project, identifier: "macroproj") }
      let(:work_package) { create(:work_package, project:, author:) }

      it "renders the numeric `#N` label and a numeric href" do
        rendered = format_text(mention_tag(work_package))

        expect(rendered).to include(">##{work_package.id}<")
        expect(rendered).to include(%(href="/work_packages/#{work_package.id}"))
        expect(rendered).to include(%(data-hover-card-url="/work_packages/#{work_package.id}/hover_card"))
      end
    end

    context "as plain link in semantic mode",
            with_flag: { semantic_work_package_ids: true },
            with_settings: { work_packages_identifier: "semantic" } do
      let(:project) { create(:project, identifier: "MACROPROJ") }
      let(:work_package) { create(:work_package, project:, author:) }

      before { work_package.allocate_and_register_semantic_id }

      it "renders the formatted_id label and the displayId in the href" do
        wp = work_package.reload
        rendered = format_text(mention_tag(wp))

        expect(wp.formatted_id).to start_with("MACROPROJ-")
        expect(rendered).to include(">#{wp.formatted_id}<")
        expect(rendered).to include(%(href="/work_packages/#{wp.display_id}"))
        expect(rendered).to include(%(data-hover-card-url="/work_packages/#{wp.display_id}/hover_card"))
        expect(rendered).not_to include(">##{wp.id}<")
      end
    end

    context "as compact quickinfo (`##`) in semantic mode",
            with_flag: { semantic_work_package_ids: true },
            with_settings: { work_packages_identifier: "semantic" } do
      let(:project) { create(:project, identifier: "MACROPROJ") }
      let(:work_package) { create(:work_package, project:, author:) }

      before { work_package.allocate_and_register_semantic_id }

      it "emits the quickinfo macro with displayId in data-id" do
        wp = work_package.reload
        rendered = format_text(mention_tag(wp, sep: "##"))

        expect(rendered).to include(%(<opce-macro-wp-quickinfo))
        expect(rendered).to include(%(data-id="#{wp.id}"))
        expect(rendered).to include(%(data-display-id="#{wp.display_id}"))
        expect(rendered).to include(%(data-detailed="false"))
      end
    end

    context "as detailed quickinfo (`###`) in semantic mode",
            with_flag: { semantic_work_package_ids: true },
            with_settings: { work_packages_identifier: "semantic" } do
      let(:project) { create(:project, identifier: "MACROPROJ") }
      let(:work_package) { create(:work_package, project:, author:) }

      before { work_package.allocate_and_register_semantic_id }

      it "emits the detailed quickinfo macro with displayId in data-id" do
        wp = work_package.reload
        rendered = format_text(mention_tag(wp, sep: "###"))

        expect(rendered).to include(%(<opce-macro-wp-quickinfo))
        expect(rendered).to include(%(data-id="#{wp.id}"))
        expect(rendered).to include(%(data-display-id="#{wp.display_id}"))
        expect(rendered).to include(%(data-detailed="true"))
      end
    end

    context "as compact quickinfo (`##`) in classic mode",
            with_flag: { semantic_work_package_ids: false },
            with_settings: { work_packages_identifier: "classic" } do
      let(:project) { create(:project, identifier: "macroproj") }
      let(:work_package) { create(:work_package, project:, author:) }

      it "emits the quickinfo macro with the numeric id (no regression)" do
        rendered = format_text(mention_tag(work_package, sep: "##"))

        expect(rendered).to include(%(<opce-macro-wp-quickinfo))
        expect(rendered).to include(%(data-id="#{work_package.id}"))
        expect(rendered).to include(%(data-display-id="#{work_package.id}"))
        expect(rendered).to include(%(data-detailed="false"))
      end
    end

    # Classic-mode rendering stays numeric even when the WP itself carries
    # a semantic identifier. Labels and URLs key off the mode, not the
    # record state.
    context "in classic mode when the WP carries a semantic identifier",
            with_flag: { semantic_work_package_ids: false },
            with_settings: { work_packages_identifier: "classic" } do
      let(:project) { create(:project, identifier: "macroproj") }
      let(:work_package) { create(:work_package, project:, author:) }
      let(:wp) { work_package.reload }

      before { work_package.allocate_and_register_semantic_id }

      it "renders the numeric `#N` label even when the WP has a semantic identifier" do
        rendered = format_text(mention_tag(wp))

        expect(wp.identifier).to be_present
        expect(rendered).to include(">##{wp.id}<")
        expect(rendered).to include(%(href="/work_packages/#{wp.id}"))
        expect(rendered).not_to include(wp.identifier)
      end
    end

    context "with an unresolvable data-id",
            with_flag: { semantic_work_package_ids: false },
            with_settings: { work_packages_identifier: "classic" } do
      let(:project) { create(:project, identifier: "macroproj") }
      let(:work_package) { create(:work_package, project:, author:) }

      it "falls back to the literal mention text without crashing" do
        tag = mention_tag(work_package, data_id: "999999999", data_text: "#999999999")

        expect { format_text(tag) }.not_to raise_error
        expect(format_text(tag)).to include("#999999999")
      end
    end

    # Semantic-shaped data-ids must not silently resolve to a WP whose id
    # matches the embedded digits.
    context "with a semantic-shaped data-id whose embedded digits collide with a real WP id",
            with_flag: { semantic_work_package_ids: false },
            with_settings: { work_packages_identifier: "classic" } do
      let(:project) { create(:project, identifier: "macroproj") }
      let(:work_package) { create(:work_package, project:, author:) }

      it "falls back to the literal mention text without resolving the wrong record" do
        tag = mention_tag(work_package,
                          data_id: "PROJ-#{work_package.id}",
                          data_text: "#PROJ-#{work_package.id}")

        rendered = format_text(tag)
        expect(rendered).to include("#PROJ-#{work_package.id}")
        expect(rendered).not_to include(%(/work_packages/#{work_package.id}))
      end
    end
  end

  describe "batching across mention classes" do
    shared_let(:role) { create(:project_role, permissions: %i[view_work_packages]) }
    shared_let(:project) { create(:project) }
    shared_let(:author) { create(:user, member_with_roles: { project => role }) }

    before { login_as(author) }

    def user_mention(user)
      %(<mention class="mention" data-id="#{user.id}" data-type="user" data-text="@#{user.name}">@#{user.name}</mention>)
    end

    def group_mention(group)
      %(<mention class="mention" data-id="#{group.id}" data-type="group" data-text="@#{group.name}">@#{group.name}</mention>)
    end

    def work_package_mention(work_package)
      id = work_package.id
      %(<mention class="mention" data-id="#{id}" data-type="work_package" data-text="##{id}">##{id}</mention>)
    end

    describe "query count" do
      let!(:users) { create_list(:user, 3, member_with_roles: { project => role }) }
      let!(:groups) { create_list(:group, 2, member_with_roles: { project => role }) }
      let!(:work_packages) { create_list(:work_package, 3, project:, author:) }

      let(:raw) do
        [
          *users.map { user_mention(it) },
          *groups.map { group_mention(it) },
          *work_packages.map { work_package_mention(it) }
        ].join(" ")
      end

      it "fetches each mention class with a single IN-batched SELECT and zero per-record find_bys" do
        recorder = ActiveRecord::QueryRecorder.new { format_text(raw) }

        principal_batched = recorder.log.grep(/SELECT "users"\..*FROM "users".*"users"\."id" IN/i)
        principal_per_record = recorder.log.grep(/SELECT "users"\..*FROM "users".*"users"\."id" = .* LIMIT/i)
        wp_batched = recorder.log.grep(/SELECT "work_packages"\..*FROM "work_packages".*"work_packages"\."id" IN/i)
        wp_per_record = recorder.log.grep(/SELECT "work_packages"\..*FROM "work_packages".*"work_packages"\."id" = .* LIMIT/i)

        # User and Group inherit Principal.visible but apply distinct STI
        # type filters, so the batched form issues one SELECT per class.
        expect(principal_batched.size).to eq(2),
                                          "expected 2 batched principal SELECTs (User + Group), " \
                                          "got #{principal_batched.size}:\n#{principal_batched.join("\n")}"
        expect(wp_batched.size).to eq(1),
                                   "expected 1 batched work_packages SELECT, got #{wp_batched.size}:\n" \
                                   "#{wp_batched.join("\n")}"
        expect(principal_per_record).to be_empty,
                                        "expected zero per-record principal find_bys, got:\n#{principal_per_record.join("\n")}"
        expect(wp_per_record).to be_empty,
                                 "expected zero per-record work_package find_bys, got:\n#{wp_per_record.join("\n")}"
      end
    end

    describe "visibility per record" do
      let!(:visible_user) { create(:user, member_with_roles: { project => role }) }
      let!(:invisible_user) { create(:user) } # no project membership, not visible to author

      it "renders visible records as links and falls back to plain text for invisible ones in the same batch" do
        raw = [user_mention(visible_user), user_mention(invisible_user)].join(" ")

        rendered = format_text(raw)

        expect(rendered).to include(%(href="/users/#{visible_user.id}"))
        expect(rendered).not_to include(%(href="/users/#{invisible_user.id}"))
        expect(rendered).to include("@#{invisible_user.name}")
      end
    end

    describe "unknown data-type" do
      it "raises ArgumentError" do
        raw = %(<mention class="mention" data-id="1" data-type="bogus" data-text="@x">@x</mention>)

        expect { format_text(raw) }.to raise_error(ArgumentError)
      end
    end
  end
end
