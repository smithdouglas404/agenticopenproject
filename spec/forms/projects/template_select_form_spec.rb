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
#
require "spec_helper"

RSpec.describe Projects::TemplateSelectForm, type: :forms do
  include_context "with rendered form"

  let(:model) { create(:project) }
  let(:params) { { template_id:, parent_id:, current_user:, workspace_type: model.workspace_type } }
  let(:current_user) { create(:admin) }

  let(:template_id) { nil }
  let(:parent_id) { nil }

  subject(:rendered_form) do
    render_form
    page
  end

  context "with no templates" do
    %i[project portfolio program].each do |workspace_type|
      context "when workspace_type is #{workspace_type}" do
        let(:model) { create(:project, workspace_type:) }

        it "renders Blank #{workspace_type.to_s.capitalize} radio button only" do
          expect(rendered_form).to have_field type: :radio, count: 1, fieldset: "Use template"
          expect(rendered_form).to have_field "Blank #{workspace_type}",
                                              type: :radio,
                                              accessible_description: /^Start from scratch.*#{workspace_type}/
        end
      end
    end
  end

  context "with templates" do
    let!(:templates) do
      [
        create(:template_project, name: "Agile", description: "**Great for beginners.**"),
        create(:template_project, name: "SAF€", description: nil),
        create(:template_project, name: "PRINCE", description: "## His Majesty's Choice.")
      ]
    end

    it "renders radio buttons for each template in addition to Blank Project", :aggregate_failures do
      expect(rendered_form).to have_field type: :radio, count: 4, fieldset: "Use template"
      expect(rendered_form).to have_field "Blank project",
                                          type: :radio,
                                          accessible_description: /^Start from scratch.*project/
      expect(rendered_form).to have_field "Agile",
                                          type: :radio,
                                          accessible_description: /^Great for beginners\.$/
      expect(rendered_form).to have_field "SAF€",
                                          type: :radio,
                                          accessible_description: /^No description provided\.$/
      expect(rendered_form).to have_field "PRINCE",
                                          type: :radio,
                                          accessible_description: /^His Majesty's Choice\.$/
    end

    context "when template_id is nil" do
      it "renders checked radio button for Blank Project" do
        expect(rendered_form).to have_checked_field "Blank project", type: :radio
      end
    end

    context "when template_id is not nil" do
      let(:template_id) { templates.last.id }

      it "renders checked radio button for given template" do
        expect(rendered_form).to have_checked_field "PRINCE", type: :radio
      end
    end
  end

  context "when parent_id is nil" do
    it "does not render hidden parent_id field" do
      expect(rendered_form).to have_no_field "parent_id", type: :hidden
    end
  end

  context "when parent_id is not nil" do
    let(:parent_id) { 42 }

    it "renders hidden parent_id field" do
      expect(rendered_form).to have_field "parent_id", type: :hidden, with: 42
    end
  end
end
