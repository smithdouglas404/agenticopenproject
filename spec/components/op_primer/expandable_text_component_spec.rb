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
        "[data-controller='truncation']" \
        "[data-truncation-mode-value='horizontal']" \
        "[data-truncation-inline-value='true']"
      )
      expect(page).to have_css(".Truncate.flex-1[data-truncation-target='truncate']", text: "Long permission label")
      expect(page).to have_css(".hidden-text-expander[data-truncation-target='expander'][hidden]", visible: :hidden)
      expect(page).to have_css("button.ellipsis-expander[aria-label='Show full text']", visible: :hidden)
    end

    it "merges classes and data attributes" do
      render_component(classes: "custom-class", data: { test_selector: "expandable-text" }) { "Long permission label" }

      expect(page).to have_css(
        "div.custom-class.gap-1.min-width-0[data-controller='truncation'][data-test-selector='expandable-text']"
      )
    end

    it "supports flex system arguments" do
      render_component(flex: 1) { "Long permission label" }

      expect(page).to have_css("div.flex-1")
    end
  end

  describe "vertical mode" do
    it "renders with line-clamp instead of Truncate" do
      render_component(truncation: :vertical, lines: 3) { "Multi-line content" }

      expect(page).to have_css(
        "div.d-flex[data-truncation-mode-value='vertical']"
      )
      expect(page).to have_css("div.line-clamp-3[data-truncation-target='truncate']", text: "Multi-line content")
      expect(page).to have_no_css(".Truncate")
    end

    it "uses flex-end alignment for vertical mode" do
      render_component(truncation: :vertical) { "Content" }

      expect(page).to have_css("div.flex-items-end")
      expect(page).to have_no_css("div.flex-items-baseline")
    end

    it "supports configurable line count" do
      render_component(truncation: :vertical, lines: 5) { "Content" }

      expect(page).to have_css("div.line-clamp-5[data-truncation-target='truncate']")
    end

    it "clamps the line count to the supported range" do
      render_component(truncation: :vertical, lines: 99) { "Content" }
      expect(page).to have_css("div.line-clamp-6[data-truncation-target='truncate']")

      render_component(truncation: :vertical, lines: 0) { "Content" }
      expect(page).to have_css("div.line-clamp-1[data-truncation-target='truncate']")
    end
  end

  describe "dialog mode (inline: false)" do
    it "sets inline value to false on controller" do
      render_component(inline: false) { "Content" }

      expect(page).to have_css("div[data-truncation-inline-value='false']")
    end
  end

  describe "expander_arguments" do
    it "merges additional arguments into the expander" do
      render_component(
        expander_arguments: { button_arguments: { "data-show-dialog-id": "my-dialog" } }
      ) { "Content" }

      expect(page).to have_css(
        ".hidden-text-expander[data-truncation-target='expander']",
        visible: :hidden
      )
    end

    it "does not mutate the caller-provided hash" do
      arguments = { mt: 3 }

      render_component(expander_arguments: arguments) { "Content" }

      expect(arguments).to eq(mt: 3)
    end
  end

  describe "validation" do
    it "raises for invalid truncation mode in development and test" do
      expect { render_component(truncation: :diagonal) { "Content" } }
        .to raise_error(Primer::FetchOrFallbackHelper::InvalidValueError)
    end
  end
end
