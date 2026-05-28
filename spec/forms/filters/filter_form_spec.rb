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

RSpec.describe Filters::FilterForm, type: :forms do
  include ViewComponent::TestHelpers

  let(:query) { UserQuery.new }

  # `Member.human_attribute_name(:blocked)` is what BlockedFilter#human_name
  # depends on; UserQuery#available_advanced_filters includes it, and we keep
  # the full set in these specs so the spec doesn't drift from production.
  let(:allowed_filters) { nil }
  let(:options) { { query:, allowed_filters: } }

  def render_form(form_options = options)
    render_in_view_context(form_options) do |form_options|
      primer_form_with(url: "/foo", method: :post) do |f|
        render(Filters::FilterForm.new(f, **form_options))
      end
    end
  end

  describe "basic rendering" do
    before { render_form }

    it "renders an Add filter select with one option per allowed filter" do
      select = page.find('select[name="add_filter_select"]')

      expect(select).to be_present
      # Sanity: at least the well-known UserQuery filters are advertised.
      expect(select.all("option").map(&:value)).to include("name", "status", "login")
    end

    it "renders a hidden row per allowed filter, plus active rows visible" do
      # Activate a single filter — its row should be rendered without `hidden`.
      query.where(:login, "=", ["alice"])
      render_form

      # `data-filter--filters-form-target="filter"` scopes to the outer row;
      # operator/value descendants also carry `data-filter-name`.
      active_row = page.find('[data-filter--filters-form-target="filter"][data-filter-name="login"]',
                             visible: :all)
      inactive_row = page.find('[data-filter--filters-form-target="filter"][data-filter-name="status"]',
                               visible: :all)

      expect(active_row["hidden"]).to be_nil
      expect(inactive_row["hidden"]).to eq("hidden")
    end
  end

  describe "allowed_filters" do
    let(:restricted) do
      query.available_advanced_filters.select { |f| f.name == :login }
    end

    it "limits the rendered Add filter options" do
      render_form(query:, allowed_filters: restricted)

      values = page.find('select[name="add_filter_select"]').all("option").map(&:value)
      expect(values).to contain_exactly("", "login")
    end
  end

  describe "wrap_with_controller:" do
    it "does not emit a controller wrapper by default" do
      render_form

      expect(page).to have_no_css('[data-controller~="filter--filters-form"]')
    end

    it "emits an `op-filters-form -expanded` controller wrapper when true" do
      render_form(query:, wrap_with_controller: true)

      wrapper = page.find('[data-controller~="filter--filters-form"]')
      expect(wrapper[:class].split).to include("op-filters-form", "-expanded")
    end
  end

  describe "hidden_input_name:" do
    it "renders no hidden filters field by default" do
      render_form

      expect(page).to have_no_css('input[data-filter--filters-form-target="filtersInput"]', visible: :all)
    end

    it "renders a hidden field bound to the filtersInput target when set" do
      render_form(query:, hidden_input_name: "filters")

      hidden = page.find('input[type="hidden"][name="filters"]', visible: :all)
      expect(hidden["data-filter--filters-form-target"]).to eq("filtersInput")
    end
  end

  describe "output_format:" do
    it "sets the controller value when wrapping the controller" do
      render_form(query:, wrap_with_controller: true, output_format: :json)

      wrapper = page.find('[data-controller~="filter--filters-form"]')
      expect(wrapper["data-filter--filters-form-output-format-value"]).to eq("json")
    end

    it "omits the data attribute by default" do
      render_form(query:, wrap_with_controller: true)

      wrapper = page.find('[data-controller~="filter--filters-form"]')
      expect(wrapper["data-filter--filters-form-output-format-value"]).to be_nil
    end

    it "raises on unknown values" do
      # `Primer::Forms::Base.new` accepts a nil builder without complaint,
      # which lets us exercise the keyword validation without spinning up
      # a real form context.
      expect do
        described_class.new(nil, query:, output_format: :bogus)
      end.to raise_error(ArgumentError, /Unknown output_format/)
    end
  end

  describe "autocomplete_append_to:" do
    let(:append_to_for) do
      ->(filter_name) do
        wrapper = page.find(%([data-filter-name="#{filter_name}"][data-filter-autocomplete="true"]), visible: :all)
        component = wrapper.find("[data-append-to]", visible: :all)
        # angular_component_tag json-encodes inputs into data attributes,
        # so `appendTo: "#dialog"` arrives as the JSON string `"#dialog"`.
        JSON.parse(component["data-append-to"])
      end
    end

    it "forwards the selector into the autocomplete options of ListForm filters" do
      render_form(query:, autocomplete_append_to: "#dialog-x")

      # :status is a list filter (no native autocomplete_options) and is
      # routed to ListForm.
      expect(append_to_for.call("status")).to eq("#dialog-x")
    end

    it "is absent from autocomplete data when not set" do
      render_form

      wrapper = page.find('[data-filter-name="status"][data-filter-autocomplete="true"]', visible: :all)
      component = wrapper.find(".op-angular-component", visible: :all)
      expect(component["data-append-to"]).to be_nil
    end
  end
end
