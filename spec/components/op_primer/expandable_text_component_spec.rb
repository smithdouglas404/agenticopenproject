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

RSpec.describe OpPrimer::ExpandableTextComponent, type: :component do
  def render_component(**, &)
    render_inline(described_class.new(**), &)
  end

  describe "horizontal mode (default)" do
    it "renders expandable truncated text" do
      render_component { "Long permission label" }

      expect(page).to have_css(
        "div.d-flex.flex-items-baseline.gap-1.min-width-0" \
        "[data-controller='expandable-text']" \
        "[data-expandable-text-mode-value='horizontal']" \
        "[data-expandable-text-inline-value='true']"
      )
      expect(page).to have_css(".Truncate.flex-1[data-expandable-text-target='truncate']", text: "Long permission label")
      expect(page).to have_css(".hidden-text-expander[data-expandable-text-target='expander'][hidden]", visible: :hidden)
      expect(page).to have_css("button.ellipsis-expander[aria-label='Show full text']", visible: :hidden)
    end

    it "merges classes and data attributes" do
      render_component(classes: "custom-class", data: { test_selector: "expandable-text" }) { "Long permission label" }

      expect(page).to have_css(
        "div.custom-class.gap-1.min-width-0[data-controller='expandable-text'][data-test-selector='expandable-text']"
      )
    end

    it "supports flex system arguments" do
      render_component(flex: 1) { "Long permission label" }

      expect(page).to have_css("div.flex-1")
    end
  end

  describe "vertical mode" do
    it "renders an op-vertical-truncate instead of a Truncate" do
      render_component(direction: :vertical, lines: 3) { "Multi-line content" }

      expect(page).to have_css(
        "div.d-flex[data-expandable-text-mode-value='vertical']"
      )
      expect(page).to have_css(
        "div.op-vertical-truncate.op-vertical-truncate--lines-3[data-expandable-text-target='truncate']",
        text: "Multi-line content"
      )
      expect(page).to have_no_css(".Truncate")
    end

    it "uses flex-end alignment for vertical mode" do
      render_component(direction: :vertical) { "Content" }

      expect(page).to have_css("div.flex-items-end")
      expect(page).to have_no_css("div.flex-items-baseline")
    end

    it "supports configurable line count" do
      render_component(direction: :vertical, lines: 5) { "Content" }

      expect(page).to have_css("div.op-vertical-truncate--lines-5[data-expandable-text-target='truncate']")
    end

    it "clamps the line count to the supported range" do
      render_component(direction: :vertical, lines: 99) { "Content" }
      expect(page).to have_css("div.op-vertical-truncate--lines-6[data-expandable-text-target='truncate']")

      render_component(direction: :vertical, lines: 0) { "Content" }
      expect(page).to have_css("div.op-vertical-truncate--lines-1[data-expandable-text-target='truncate']")
    end
  end

  describe "external expansion (expansion: :external)" do
    it "sets the inline value to false on the controller" do
      render_component(expansion: :external) { "Content" }

      expect(page).to have_css("div[data-expandable-text-inline-value='false']")
    end
  end

  describe "expander_arguments" do
    it "merges additional arguments into the expander" do
      render_component(
        expander_arguments: { button_arguments: { "data-show-dialog-id": "my-dialog" } }
      ) { "Content" }

      expect(page).to have_css(
        ".hidden-text-expander[data-expandable-text-target='expander']",
        visible: :hidden
      )
    end

    it "does not mutate the caller-provided hash, including nested button_arguments" do
      arguments = { mt: 3, button_arguments: { classes: "x" } }

      render_component(expander_arguments: arguments) { "Content" }

      expect(arguments).to eq(mt: 3, button_arguments: { classes: "x" })
    end
  end

  describe "validation" do
    it "raises for an invalid direction in development and test" do
      expect { render_component(direction: :diagonal) { "Content" } }
        .to raise_error(Primer::FetchOrFallbackHelper::InvalidValueError)
    end

    it "raises for an invalid expansion in development and test" do
      expect { render_component(expansion: :sideways) { "Content" } }
        .to raise_error(Primer::FetchOrFallbackHelper::InvalidValueError)
    end
  end
end
