# frozen_string_literal: true

require "spec_helper"
require_relative "../../markdown/expected_markdown"

RSpec.describe OpenProject::TextFormatting::Matchers::LinkHandlers::WorkPackages do
  include_context "expected markdown modules"

  describe "the `#N` plain reference" do
    let(:role) { create(:project_role, permissions: %i[view_work_packages]) }
    let(:author) { create(:user, member_with_roles: { project => role }) }
    let(:work_package) { create(:work_package, project:, author:) }

    before { allow(User).to receive(:current).and_return(author) }

    context "in classic mode",
            with_flag: { semantic_work_package_ids: false },
            with_settings: { work_packages_identifier: "classic" } do
      let(:project) { create(:project, identifier: "macroproj") }

      it "renders the numeric id with a `#` prefix and a numeric href" do
        rendered = format_text("##{work_package.id}")

        expect(rendered).to include(">##{work_package.id}<")
        expect(rendered).to include(%(href="/work_packages/#{work_package.id}"))
      end
    end

    context "in semantic mode",
            with_flag: { semantic_work_package_ids: true },
            with_settings: { work_packages_identifier: "semantic" } do
      let(:project) { create(:project, identifier: "MACROPROJ") }

      before { work_package.allocate_and_register_semantic_id }

      it "renders the formatted_id (PROJ-N) and the displayId in the href" do
        wp = work_package.reload
        rendered = format_text("##{wp.id}")

        expect(wp.formatted_id).to start_with("MACROPROJ-")
        expect(rendered).to include(">#{wp.formatted_id}<")
        expect(rendered).to include(%(href="/work_packages/#{wp.display_id}"))
        expect(rendered).not_to include(">##{wp.id}<")
      end
    end

    context "when the referenced work package does not exist",
            with_flag: { semantic_work_package_ids: true },
            with_settings: { work_packages_identifier: "semantic" } do
      let(:project) { create(:project, identifier: "MACROPROJ") }

      it "falls back to the numeric label and href (no DB error)" do
        # Realise project + author so format_text has a current user, but
        # do not realise work_package — we want to render a `#N` reference
        # whose id has no matching record.
        project
        author

        rendered = format_text("#999999")

        # Fallback path: the matcher cannot resolve the WP, so it preserves
        # the legacy `#N` shape rather than 404-ing the render.
        expect(rendered).to include(">#999999<")
        expect(rendered).to include(%(href="/work_packages/999999"))
      end
    end
  end

  describe ".with_preloaded_resources save/restore semantics",
           with_flag: { semantic_work_package_ids: true },
           with_settings: { work_packages_identifier: "semantic" } do
    # A custom-field formatter or recursive markdown render may invoke the
    # text-formatting pipeline while an outer render is mid-iteration. The
    # lookup must save on entry and restore on exit so the outer render's
    # remaining `#N` matchers still see its WPs after the inner call returns.
    let(:project) { create(:project, identifier: "NESTED") }
    let(:author) { create(:user, member_with_roles: { project => role }) }
    let(:role) { create(:project_role, permissions: %i[view_work_packages]) }
    let(:outer_wp) { create(:work_package, project:, author:) }
    let(:inner_wp) { create(:work_package, project:, author:) }
    let(:matcher) { OpenProject::TextFormatting::Matchers::ResourceLinksMatcher }

    before do
      allow(User).to receive(:current).and_return(author)
      outer_wp.allocate_and_register_semantic_id
      inner_wp.allocate_and_register_semantic_id
    end

    it "preserves the outer lookup across a nested call" do
      outer = outer_wp.reload
      inner = inner_wp.reload
      outer_doc = Nokogiri::HTML.fragment("##{outer.id}")
      inner_doc = Nokogiri::HTML.fragment("##{inner.id}")

      matcher.with_preloaded_resources(outer_doc, {}) do
        expect(matcher.work_package_for(outer.id)).to eq(outer)

        matcher.with_preloaded_resources(inner_doc, {}) do
          expect(matcher.work_package_for(inner.id)).to eq(inner)
        end

        expect(matcher.work_package_for(outer.id))
          .to eq(outer), "outer lookup should be restored after nested call"
      end

      expect(matcher.work_package_for(outer.id)).to be_nil
    end
  end

  describe "classic mode is query-free",
           with_flag: { semantic_work_package_ids: false },
           with_settings: { work_packages_identifier: "classic" } do
    # Pre-PR-E behaviour: rendering a `#N` reference in classic mode does no
    # WorkPackage SELECTs. Preserve that — the preload must be a no-op when
    # `display_id` and `formatted_id` would collapse to the numeric form.
    let(:role) { create(:project_role, permissions: %i[view_work_packages]) }
    let(:project) { create(:project, identifier: "classicproj") }
    let(:author) { create(:user, member_with_roles: { project => role }) }

    before { allow(User).to receive(:current).and_return(author) }

    it "does not query work_packages when rendering #N" do
      wps = create_list(:work_package, 3, project:, author:)
      ids_text = wps.map { |wp| "##{wp.id}" }.join(" ")

      sql = []
      callback = ->(_, _, _, _, v) { sql << v[:sql] unless %w[CACHE SCHEMA].include?(v[:name]) }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { format_text(ids_text) }

      wp_selects = sql.grep(/FROM "work_packages"/i)
      expect(wp_selects).to be_empty, "classic mode added unexpected WP SELECTs:\n#{wp_selects.join("\n")}"
    end
  end

  describe "N+1 query bound" do
    let(:role) { create(:project_role, permissions: %i[view_work_packages]) }
    let(:project) { create(:project, identifier: "NPLUSONE") }
    let(:author) { create(:user, member_with_roles: { project => role }) }

    before { allow(User).to receive(:current).and_return(author) }

    it "loads referenced work packages with a single query regardless of count",
       with_flag: { semantic_work_package_ids: true },
       with_settings: { work_packages_identifier: "semantic" } do
      wps = create_list(:work_package, 5, project:, author:)
      ids_text = wps.map { |wp| "##{wp.id}" }.join(" ")

      expect { format_text(ids_text) }.to have_a_query_limit(1)
    end
  end
end
