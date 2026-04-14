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

# InboxItemComponent renders into a Primer::Beta::BorderBox container slot,
# so it is tested through InboxComponent which provides the container.
RSpec.describe Backlogs::InboxItemComponent, type: :component do
  include Rails.application.routes.url_helpers

  shared_let(:default_status) { create(:default_status) }
  shared_let(:default_priority) { create(:default_priority) }
  shared_let(:user) { create(:admin) }
  current_user { user }

  let(:project) { create(:project) }
  let(:work_package) do
    create(:work_package,
           subject: "Inbox Work Package",
           project:,
           status: default_status,
           priority: default_priority,
           position: 1)
  end
  let(:work_packages) { WorkPackage.where(id: work_package.id).order(Arel.sql(Story::ORDER)) }

  before do
    render_inline(
      Backlogs::InboxComponent.new(
        work_packages:,
        project:,
        current_user: user
      )
    )
  end

  it "rendering renders the Inbox Component", :aggregate_failures do
    # renders the work package subject
    expect(page).to have_text("Inbox Work Package")
    # renders a drag handle
    expect(page).to have_octicon(:grabber)
    # renders WorkPackages::InfoLineComponent with type and ID
    expect(page).to have_text("##{work_package.id}")
    # deferred action menu (kebab + include-fragment src)
    expect(page).to have_css("action-menu")
    expect(page).to have_css(%(include-fragment[src*="menu"]))
    expect(page).to have_element(:button, id: /\Awork_package_#{work_package.id}_menu-button\z/)
  end

  describe "row data attributes" do
    subject(:row) { page.find(".Box-row#work_package_#{work_package.id}") }

    it "sets the work package DOM id on the row" do
      expect(page).to have_css(".Box-row#work_package_#{work_package.id}")
    end

    it "sets the backlogs--story Stimulus controller" do
      expect(row["data-controller"]).to eq("backlogs--story")
    end

    it "sets the split-view and full-view URLs for the story controller" do
      expect(row["data-backlogs--story-split-url-value"])
        .to end_with(details_backlogs_project_backlogs_path(project, work_package))
      expect(row["data-backlogs--story-full-url-value"])
        .to end_with(work_package_path(work_package))
    end

    it "applies the correct row CSS classes" do
      expect(row[:class]).to include("Box-row--hover-blue", "Box-row--focus-gray",
                                     "Box-row--clickable", "Box-row--draggable")
    end
  end
end
