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

RSpec.describe Projects::NewComponent, type: :component do
  let(:project) { build_stubbed(:project) }
  let(:template) { nil }
  let(:copy_options) { nil }

  def render_component
    render_inline(described_class.new(project:, template:, copy_options:))
    page
  end

  it "renders a form" do
    expect(render_component).to have_css "form"
  end

  context "when creating from scratch" do
    it "renders custom fields form" do
      allow(Projects::Settings::CustomFieldsForm).to receive(:new).and_call_original
      render_component
      expect(Projects::Settings::CustomFieldsForm).to have_received(:new)
    end
  end

  context "when creating from template" do
    let(:template) { build_stubbed(:template_project) }
    let(:copy_options) { Projects::CopyOptions.new }

    it "does not render custom fields form" do
      allow(Projects::Settings::CustomFieldsForm).to receive(:new)
      render_component
      expect(Projects::Settings::CustomFieldsForm).not_to have_received(:new)
    end

    it "renders template form" do
      allow(Projects::TemplateForm).to receive(:new).and_call_original
      render_component
      expect(Projects::TemplateForm).to have_received(:new).with(anything, template:, copy_options:)
    end
  end
end
