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

    it "loads referenced work packages with a single SELECT regardless of count",
       with_flag: { semantic_work_package_ids: true },
       with_settings: { work_packages_identifier: "semantic" } do
      wps = create_list(:work_package, 5, project:, author:)
      ids_text = wps.map { |wp| "##{wp.id}" }.join(" ")

      sql = []
      callback = ->(_, _, _, _, v) { sql << v[:sql] unless %w[CACHE SCHEMA].include?(v[:name]) }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { format_text(ids_text) }

      # Filter to only `work_packages` SELECTs — incidental Setting/User/Project
      # queries during render are unrelated to the N+1 bound this spec asserts.
      wp_selects = sql.grep(/FROM "work_packages"/i)
      expect(wp_selects.size).to eq(1),
                                 "expected exactly one work_packages SELECT, got #{wp_selects.size}:\n#{wp_selects.join("\n")}"
    end
  end

  describe "the `#PROJ-N` semantic reference",
           with_flag: { semantic_work_package_ids: true },
           with_settings: { work_packages_identifier: "semantic" } do
    let(:role) { create(:project_role, permissions: %i[view_work_packages]) }
    let(:author) { create(:user, member_with_roles: { project => role }) }
    let(:project) { create(:project, identifier: "MACROPROJ") }
    let(:work_package) { create(:work_package, project:, author:) }

    before do
      allow(User).to receive(:current).and_return(author)
      work_package.allocate_and_register_semantic_id
    end

    it "renders the formatted_id label and display_id href for `#PROJ-N`" do
      wp = work_package.reload
      rendered = format_text("##{wp.display_id}")

      expect(wp.display_id).to start_with("MACROPROJ-")
      expect(rendered).to include(">#{wp.formatted_id}<")
      expect(rendered).to include(%(href="/work_packages/#{wp.display_id}"))
      # Hover-card URL also speaks the user-facing identifier — the
      # controller's HoverCardComponent calls find_by_display_id, so the
      # numeric and semantic shapes both resolve.
      expect(rendered).to include(%(data-hover-card-url="/work_packages/#{wp.display_id}/hover_card"))
    end

    it "renders `##PROJ-N` as a quickinfo macro element with display_id in data-id" do
      wp = work_package.reload
      # Prepend "see " so Markly doesn't parse `##...` as an H2 ATX heading.
      rendered = format_text("see ###{wp.display_id} here")

      expect(rendered).to include(%(<opce-macro-wp-quickinfo data-id="#{wp.display_id}" data-detailed="false">))
    end

    it "renders `###PROJ-N` as a detailed quickinfo macro element" do
      wp = work_package.reload
      rendered = format_text("see ####{wp.display_id} here")

      expect(rendered).to include(%(<opce-macro-wp-quickinfo data-id="#{wp.display_id}" data-detailed="true">))
    end

    context "when the referenced work package does not exist" do
      it "falls back to literal text (no DB error, no broken link)" do
        rendered = format_text("see #GHOST-99 here")

        # No `<a>` tag, no quickinfo element — the matcher leaves the literal
        # text alone when a semantic-shaped reference can't be resolved. This
        # mirrors the user expectation: a `/work_packages/GHOST-99` URL would
        # 404, so we'd rather show the bare text.
        expect(rendered).to include("#GHOST-99")
        expect(rendered).not_to include('href="/work_packages/GHOST-99"')
        expect(rendered).not_to include("opce-macro-wp-quickinfo")
      end
    end

    context "with mixed numeric and semantic references in one render" do
      it "resolves both with a single work_packages SELECT" do
        wps = create_list(:work_package, 2, project:, author:)
        wps.each(&:allocate_and_register_semantic_id)
        loaded = wps.map(&:reload)

        text = "see ##{loaded[0].id} and ##{loaded[1].display_id}"

        sql = []
        callback = ->(_, _, _, _, v) { sql << v[:sql] unless %w[CACHE SCHEMA].include?(v[:name]) }
        rendered = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { format_text(text) }

        wp_selects = sql.grep(/FROM "work_packages"/i)
        expect(wp_selects.size).to eq(1),
                                   "expected exactly one work_packages SELECT, got #{wp_selects.size}:\n#{wp_selects.join("\n")}"

        # Both render with the user-facing display_id, regardless of which
        # form the user typed.
        expect(rendered).to include(%(href="/work_packages/#{loaded[0].display_id}"))
        expect(rendered).to include(%(href="/work_packages/#{loaded[1].display_id}"))
      end
    end

    context "with a historical alias reference" do
      it "resolves via the alias table with two round-trips total" do
        wp = work_package.reload
        # Simulate a project rename: the WP keeps its current MACROPROJ-N
        # identifier on the row, but a historical OLD-prefix alias row points
        # at the same WP. Authors writing pre-rename content shouldn't see
        # broken refs.
        WorkPackageSemanticAlias.create!(work_package_id: wp.id, identifier: "OLDPROJ-1")

        sql = []
        callback = ->(_, _, _, _, v) { sql << v[:sql] unless %w[CACHE SCHEMA].include?(v[:name]) }
        rendered = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { format_text("see #OLDPROJ-1") }

        # Two database round-trips: (1) `where_display_id_in` runs a single
        # WP SELECT whose WHERE clause includes an EXISTS subquery against
        # the alias table (matching by historical identifier); (2) the
        # sidecar alias pluck maps the historical input string back to its
        # WP for the cache. Round-trips are what we care about for N+1, not
        # which tables show up in each query.
        wp_selects = sql.grep(/FROM "work_packages"/i)
        standalone_alias_selects = sql.grep(/FROM "work_package_semantic_aliases"/i)
                                      .grep_v(/FROM "work_packages"/i)
        expect(wp_selects.size).to eq(1)
        expect(standalone_alias_selects.size).to eq(1)

        # Renders against the WP's CURRENT display_id, not the historical
        # alias the user typed — old content stays alive but points at the
        # current identifier.
        expect(rendered).to include(%(href="/work_packages/#{wp.display_id}"))
        expect(rendered).to include(">#{wp.formatted_id}<")
      end
    end
  end

  describe "the `#PROJ-N` semantic reference in classic mode",
           with_flag: { semantic_work_package_ids: false },
           with_settings: { work_packages_identifier: "classic" } do
    let(:role) { create(:project_role, permissions: %i[view_work_packages]) }
    let(:project) { create(:project, identifier: "macroproj") }
    let(:author) { create(:user, member_with_roles: { project => role }) }

    before { allow(User).to receive(:current).and_return(author) }

    it "leaves `#PROJ-1` as literal text and issues no work_packages SELECTs" do
      sql = []
      callback = ->(_, _, _, _, v) { sql << v[:sql] unless %w[CACHE SCHEMA].include?(v[:name]) }
      rendered = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { format_text("see #PROJ-1 here") }

      expect(rendered).to include("#PROJ-1")
      expect(rendered).not_to include('href="/work_packages/PROJ-1"')

      wp_selects = sql.grep(/FROM "work_packages"/i)
      expect(wp_selects).to be_empty,
                            "classic mode added unexpected WP SELECTs for semantic input:\n#{wp_selects.join("\n")}"
    end
  end
end
