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

RSpec.describe OpPrimer::InlineMessageComponent, type: :component do
  def render_component(**, &)
    render_inline(described_class.new(**), &)
  end

  shared_examples_for "rendering container" do |size:, variant:|
    it "renders container with data attributes" do
      expect(rendered_component).to have_element :div, "data-size": size.to_s, "data-variant": variant.to_s
    end
  end

  shared_examples_for "rendering icon" do |icon|
    it "renders #{icon} icon" do
      expect(rendered_component).to have_octicon icon
    end
  end

  context "with content" do
    subject(:rendered_component) do
      render_component(scheme: :warning) { "Important Message" }
    end

    it "applies classes", :aggregate_classes do
      expect(rendered_component).to have_css ".InlineMessage" do |container|
        expect(container).to have_css ".InlineMessageIcon"
      end
    end

    it "renders text" do
      expect(rendered_component).to have_text "Important Message"
    end
  end

  context "with blank content" do
    subject(:rendered_component) do
      render_component(scheme: :warning) { " " }
    end

    it "renders nothing" do
      expect(rendered_component.to_s).to be_empty
    end
  end

  context "with default (medium) size" do
    subject(:rendered_component) do
      render_component(scheme:) { "Important Message" }
    end

    context "with :warning scheme" do
      let(:scheme) { :warning }

      include_examples "rendering container", size: :medium, variant: :warning
      include_examples "rendering icon", :alert
    end

    context "with :critical scheme" do
      let(:scheme) { :critical }

      include_examples "rendering container", size: :medium, variant: :critical
      include_examples "rendering icon", :alert
    end

    context "with :success scheme" do
      let(:scheme) { :success }

      include_examples "rendering container", size: :medium, variant: :success
      include_examples "rendering icon", :"check-circle"
    end

    context "with :unavailable scheme" do
      let(:scheme) { :unavailable }

      include_examples "rendering container", size: :medium, variant: :unavailable
      include_examples "rendering icon", :alert
    end
  end

  context "with small size" do
    subject(:rendered_component) do
      render_component(scheme:, size: :small) { "Important Message" }
    end

    context "with :warning scheme" do
      let(:scheme) { :warning }

      include_examples "rendering container", size: :small, variant: :warning
      include_examples "rendering icon", :"alert-fill"
    end

    context "with :critical scheme" do
      let(:scheme) { :critical }

      include_examples "rendering container", size: :small, variant: :critical
      include_examples "rendering icon", :"alert-fill"
    end

    context "with :success scheme" do
      let(:scheme) { :success }

      include_examples "rendering container", size: :small, variant: :success
      include_examples "rendering icon", :"check-circle-fill"
    end

    context "with :unavailable scheme" do
      let(:scheme) { :unavailable }

      include_examples "rendering container", size: :small, variant: :unavailable
      include_examples "rendering icon", :"alert-fill"
    end
  end
end
