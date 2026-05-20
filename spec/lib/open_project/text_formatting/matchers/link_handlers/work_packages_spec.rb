# frozen_string_literal: true

require "spec_helper"
require_relative "../../markdown/expected_markdown"

RSpec.describe OpenProject::TextFormatting::Matchers::LinkHandlers::WorkPackages do
  include_context "expected markdown modules"

  # Boilerplate for the typical "current user can view a WP in this project"
  # setup. Consumers must define `:project`; `author` is realised eagerly via
  # the stubbed `User.current` so role/membership creation runs once per
  # example.
  shared_context "with author signed in" do
    let(:role) { create(:project_role, permissions: %i[view_work_packages]) }
    let(:author) { create(:user, member_with_roles: { project => role }) }

    before { allow(User).to receive(:current).and_return(author) }
  end

  describe "the `#N` plain reference" do
    include_context "with author signed in"
    let(:work_package) { create(:work_package, project:, author:) }

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
        # do not realise work_package — render a `#N` reference whose id
        # has no matching record.
        project
        author

        rendered = format_text("#999999")

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
    include_context "with author signed in"

    let(:project) { create(:project, identifier: "NESTED") }
    let(:outer_wp) { create(:work_package, project:, author:) }
    let(:inner_wp) { create(:work_package, project:, author:) }
    let(:matcher) { OpenProject::TextFormatting::Matchers::ResourceLinksMatcher }

    before do
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
    # Rendering a `#N` reference in classic mode must not run any
    # WorkPackage SELECTs: the preload is a no-op when `display_id` and
    # `formatted_id` would collapse to the numeric form, so the link
    # handler can build the link from the matched id alone.
    include_context "with author signed in"
    let(:project) { create(:project, identifier: "classicproj") }

    it "does not query work_packages when rendering #N" do
      wps = create_list(:work_package, 3, project:, author:)
      ids_text = wps.map { |wp| "##{wp.id}" }.join(" ")

      recorder = ActiveRecord::QueryRecorder.new { format_text(ids_text) }
      wp_selects = recorder.log.grep(/FROM "work_packages"/i)

      expect(wp_selects).to be_empty,
                            "classic mode added unexpected WP SELECTs:\n#{wp_selects.join("\n")}"
    end
  end

  describe "N+1 query bound",
           with_flag: { semantic_work_package_ids: true },
           with_settings: { work_packages_identifier: "semantic" } do
    include_context "with author signed in"
    let(:project) { create(:project, identifier: "NPLUSONE") }

    it "loads referenced work packages with a single SELECT regardless of count" do
      wps = create_list(:work_package, 5, project:, author:)
      ids_text = wps.map { |wp| "##{wp.id}" }.join(" ")

      recorder = ActiveRecord::QueryRecorder.new { format_text(ids_text) }
      wp_selects = recorder.log.grep(/FROM "work_packages"/i)

      expect(wp_selects.size).to eq(1),
                                 "expected exactly one work_packages SELECT, got #{wp_selects.size}:\n#{wp_selects.join("\n")}"
    end
  end

  describe "the `#PROJ-N` semantic reference",
           with_flag: { semantic_work_package_ids: true },
           with_settings: { work_packages_identifier: "semantic" } do
    include_context "with author signed in"
    let(:project) { create(:project, identifier: "MACROPROJ") }
    let(:work_package) { create(:work_package, project:, author:) }

    before { work_package.allocate_and_register_semantic_id }

    it "renders the formatted_id label and display_id href for `#PROJ-N`" do
      wp = work_package.reload
      rendered = format_text("##{wp.display_id}")

      expect(wp.display_id).to start_with("MACROPROJ-")
      expect(rendered).to include(">#{wp.formatted_id}<")
      expect(rendered).to include(%(href="/work_packages/#{wp.display_id}"))
      # The hover-card route accepts both numeric and semantic ids; pass
      # display_id so the URL matches the user-facing identifier.
      expect(rendered).to include(%(data-hover-card-url="/work_packages/#{wp.display_id}/hover_card"))
    end

    it "renders `##PROJ-N` as a quickinfo macro element with id and displayId" do
      wp = work_package.reload
      # Prepend "see " so Markly doesn't parse `##...` as an H2 ATX heading.
      rendered = format_text("see ###{wp.display_id} here")

      expect(rendered).to include(
        %(<opce-macro-wp-quickinfo data-id="#{wp.id}" data-display-id="#{wp.display_id}" data-detailed="false">)
      )
    end

    it "renders `###PROJ-N` as a detailed quickinfo macro element" do
      wp = work_package.reload
      rendered = format_text("see ####{wp.display_id} here")

      expect(rendered).to include(
        %(<opce-macro-wp-quickinfo data-id="#{wp.id}" data-display-id="#{wp.display_id}" data-detailed="true">)
      )
    end

    context "when the referenced work package does not exist" do
      it "falls back to literal text (no DB error, no broken link)" do
        rendered = format_text("see #GHOST-99 here")

        # The matcher leaves the literal text alone when a semantic-shaped
        # reference can't be resolved — better than emitting a link to
        # `/work_packages/GHOST-99` that 404s.
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

        rendered = nil
        recorder = ActiveRecord::QueryRecorder.new { rendered = format_text(text) }
        wp_selects = recorder.log.grep(/FROM "work_packages"/i)

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
        # identifier on the row, but a historical OLD-prefix alias row
        # points at the same WP. Authors writing pre-rename content
        # shouldn't see broken refs.
        WorkPackageSemanticAlias.create!(work_package_id: wp.id, identifier: "OLDPROJ-1")

        rendered = nil
        recorder = ActiveRecord::QueryRecorder.new { rendered = format_text("see #OLDPROJ-1") }

        # Two database round-trips: (1) `where_display_id_in` runs a
        # single WP SELECT whose WHERE clause includes an EXISTS
        # subquery against the alias table; (2) a sidecar alias pluck
        # maps the historical input string back to its WP for the
        # cache. A third statement would indicate an N+1 regression.
        expect(recorder.log.size).to eq(2)
        expect(recorder.log.last).to match(/FROM "work_package_semantic_aliases"/)

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
    include_context "with author signed in"
    let(:project) { create(:project, identifier: "macroproj") }

    it "leaves `#PROJ-1` as literal text and issues no work_packages SELECTs" do
      rendered = nil
      recorder = ActiveRecord::QueryRecorder.new { rendered = format_text("see #PROJ-1 here") }
      wp_selects = recorder.log.grep(/FROM "work_packages"/i)

      expect(rendered).to include("#PROJ-1")
      expect(rendered).not_to include('href="/work_packages/PROJ-1"')
      expect(wp_selects).to be_empty,
                            "classic mode added unexpected WP SELECTs for semantic input:\n#{wp_selects.join("\n")}"
    end
  end

  describe "prefixed resource refs with semantic-shaped identifiers",
           with_flag: { semantic_work_package_ids: true },
           with_settings: { work_packages_identifier: "semantic" } do
    # `version#PROJ-1`, `message#PROJ-1`, etc. share the regex with the WP
    # macro because `\d+|PROJ-\d+` is a single alternation. The prefixed
    # branches address tables keyed by numeric primary key, so a semantic
    # identifier paired with a prefix must short-circuit before the handler
    # would otherwise issue `find_by(id: 0)` (the round-trip of any
    # non-numeric string through `to_i`).
    include_context "with author signed in"
    let(:project) { create(:project, identifier: "MACROPROJ") }

    it "does not query the prefixed resource table for `version#PROJ-1`" do
      project
      author

      rendered = nil
      recorder = ActiveRecord::QueryRecorder.new { rendered = format_text("see version#PROJ-1 here") }
      version_selects = recorder.log.grep(/FROM "versions"/i)

      expect(version_selects).to be_empty,
                                 "expected zero versions SELECTs for semantic-shaped input, got:\n" \
                                 "#{version_selects.join("\n")}"
      expect(rendered).to include("version#PROJ-1")
    end
  end

  describe "visibility scoping",
           with_flag: { semantic_work_package_ids: true },
           with_settings: { work_packages_identifier: "semantic" } do
    # The lookup cache must scope through `WorkPackage.visible` —
    # anything it surfaces ends up in the rendered link, so an
    # unscoped cache would let any user read back the project
    # identifier of a WP just by guessing its primary key, semantic
    # identifier, or historical alias.
    include_context "with author signed in"

    let(:project) { create(:project, identifier: "VISIBLE") }
    let(:hidden_project) { create(:project, identifier: "HIDDEN") }
    let(:visible_wp) { create(:work_package, project:, author:) }
    let(:hidden_wp) { create(:work_package, project: hidden_project) }

    before do
      visible_wp.allocate_and_register_semantic_id
      hidden_wp.allocate_and_register_semantic_id
    end

    context "with a semantic-shaped ref to an inaccessible work package" do
      it "renders literal text and never surfaces the WP's display id" do
        wp = hidden_wp.reload
        rendered = format_text("see ##{wp.display_id} here")

        expect(rendered).to include("##{wp.display_id}")
        expect(rendered).not_to include(%(href="/work_packages/#{wp.display_id}"))
        expect(rendered).not_to include("opce-macro-wp-quickinfo")
      end
    end

    context "with a numeric ref to an inaccessible work package in semantic mode" do
      it "renders the numeric label and href without upgrading to the semantic identifier" do
        wp = hidden_wp.reload
        rendered = format_text("see ##{wp.id} here")

        # The link still renders — `#42` was already in the user's input —
        # but the upgrade to the WP's `formatted_id` / `display_id` (which
        # would leak the project identifier) does not happen.
        expect(rendered).to include(%(href="/work_packages/#{wp.id}"))
        expect(rendered).to include(">##{wp.id}<")
        expect(rendered).not_to include(%(href="/work_packages/#{wp.display_id}"))
        expect(rendered).not_to include(">#{wp.formatted_id}<")
      end
    end

    context "with a historical alias for an inaccessible work package" do
      it "renders literal text and does not resolve via the alias table" do
        wp = hidden_wp.reload
        WorkPackageSemanticAlias.create!(work_package_id: wp.id, identifier: "OLDHIDDEN-1")

        rendered = format_text("see #OLDHIDDEN-1 here")

        expect(rendered).to include("#OLDHIDDEN-1")
        expect(rendered).not_to include(%(href="/work_packages/#{wp.display_id}"))
        expect(rendered).not_to include(">#{wp.formatted_id}<")
      end
    end

    context "with visible and invisible refs mixed in one input" do
      it "renders the visible ref normally and falls back to literal text for the invisible one" do
        visible = visible_wp.reload
        hidden = hidden_wp.reload
        rendered = format_text("see ##{visible.display_id} and ##{hidden.display_id}")

        expect(rendered).to include(%(href="/work_packages/#{visible.display_id}"))
        expect(rendered).to include(">#{visible.formatted_id}<")

        expect(rendered).not_to include(%(href="/work_packages/#{hidden.display_id}"))
        expect(rendered).to include("##{hidden.display_id}")
      end
    end
  end
end
