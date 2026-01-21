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

RSpec.describe Primer::OpenProject::Forms::FieldsetGroup, type: :forms do
  include ViewComponent::TestHelpers

  describe "rendering" do
    let(:params) { {} }
    let(:model) { build_stubbed(:comment) }

    def render_form
      render_in_view_context(model, params) do |model, params|
        primer_form_with(url: "/foo", model:) do |f|
          render_inline_form(f) do |check_form|
            check_form.fieldset_group(title: "Ultimate answers", **params) do |group|
              group.check_box(name: :one, label: "One", caption: "Pick me")
              group.check_box(name: :two, label: "Two", caption: "Don't pick me")
              group.check_box(name: :three, label: "Three")
            end
          end
        end
      end
    end

    subject(:rendered_form) do
      render_form
      page
    end

    it "renders the heading (default level 3)" do
      expect(rendered_form).to have_selector :heading, "Ultimate answers", level: 3
    end

    it "renders the section" do
      expect(rendered_form).to have_selector :section, "Ultimate answers"
    end

    it "renders the fieldset" do
      expect(rendered_form).to have_selector :fieldset, "Ultimate answers"
    end

    it "renders the fields" do
      expect(rendered_form).to have_field count: 3, type: :checkbox, fieldset: "Ultimate answers"
    end
  end
end
