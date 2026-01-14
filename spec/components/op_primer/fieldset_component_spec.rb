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

RSpec.describe OpPrimer::FieldsetComponent, type: :component do
  def render_component(**, &)
    render_inline(described_class.new(**), &)
  end

  shared_examples_for "rendering fieldset" do
    it "renders fieldset" do
      expect(rendered_component).to have_element :fieldset do |fieldset|
        expect(fieldset).to have_element :legend, text: "My legend"
        expect(fieldset).to have_content "Fieldset content"
      end
    end
  end

  context "with legend slot and text param" do
    subject(:rendered_component) do
      render_component do |component|
        component.with_legend(text: "My legend")

        "Fieldset content"
      end
    end

    it_behaves_like "rendering fieldset"
  end

  context "with legend slot and content" do
    subject(:rendered_component) do
      render_component do |component|
        component.with_legend { "My legend" }

        "Fieldset content"
      end
    end

    it_behaves_like "rendering fieldset"
  end

  context "with legend_text" do
    subject(:rendered_component) do
      render_component(legend_text: "My legend") do
        "Fieldset content"
      end
    end

    it_behaves_like "rendering fieldset"
  end

  context "without legend slot or legend_text" do
    subject(:rendered_component) do
      render_component do
        "Fieldset content"
      end
    end

    it "renders nothing" do
      expect(rendered_component.to_s).to be_blank
    end
  end

  context "without content" do
    subject(:rendered_component) do
      render_component(legend_text: "My legend")
    end

    it "renders nothing" do
      expect(rendered_component.to_s).to be_blank
    end
  end
end
