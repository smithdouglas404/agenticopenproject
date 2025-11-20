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

RSpec.describe Projects::TemplateSelectComponent, type: :component do
  def render_component(...)
    render_inline(described_class.new(...))
  end

  let(:project) { Project.new }
  let(:template) { build_stubbed(:template_project) }
  let(:current_user) { build_stubbed(:user) }

  subject(:rendered_component) { render_component(project:, template:, current_user:) }

  it "renders form" do
    expect(rendered_component).to have_element :form, method: "get"
  end

  describe "action" do
    let(:project) { Project.new(workspace_type:) }

    context "when workspace type is not set" do
      let(:workspace_type) { nil }

      it "sets action to create project" do
        expect(rendered_component).to have_element :form, method: "get" do |form|
          expect(form["action"]).to eq "/projects/new"
        end
      end
    end

    context "when workspace type set to unknown value" do
      let(:workspace_type) { :unknown }

      it "sets action to create project" do
        expect(rendered_component).to have_element :form, method: "get" do |form|
          expect(form["action"]).to eq "/projects/new"
        end
      end
    end

    context "when workspace type is set to project" do
      let(:workspace_type) { :project }

      it "sets action to create project" do
        expect(rendered_component).to have_element :form, method: "get" do |form|
          expect(form["action"]).to eq "/projects/new"
        end
      end
    end

    context "when workspace type is set to program" do
      let(:workspace_type) { :program }

      it "sets action to create project" do
        expect(rendered_component).to have_element :form, method: "get" do |form|
          expect(form["action"]).to eq "/programs/new"
        end
      end
    end

    context "when workspace type is set to portfolio" do
      let(:workspace_type) { :portfolio }

      it "sets action to create project" do
        expect(rendered_component).to have_element :form, method: "get" do |form|
          expect(form["action"]).to eq "/portfolios/new"
        end
      end
    end
  end

  it "registers Stimulus controller" do
    expect(rendered_component).to have_element :form do |form|
      expect(form["data-controller"]).to include "auto-submit"
    end
  end

  it "connects Stimulus controller actions" do
    expect(rendered_component).to have_selector :fieldset, "Use template" do |fieldset|
      expect(fieldset["data-action"]).to include "change->auto-submit#submit"
    end
  end
end
