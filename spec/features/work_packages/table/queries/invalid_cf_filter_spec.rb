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

RSpec.describe "Work package filtering with an invalid custom field", :js do
  let(:project) { create(:project) }
  let(:type) { project.types.first }
  let(:wp_table) { Pages::WorkPackagesTable.new(project) }
  let(:filters) { Components::WorkPackages::Filters.new }
  let!(:bool_cf) do
    create(:boolean_wp_custom_field) do |cf|
      cf.is_filter = true
      type.custom_fields << cf
      project.work_package_custom_fields << cf
    end
  end
  let(:role) { create(:project_role, permissions: %i[view_work_packages save_queries]) }
  let(:user) do
    create(:user,
           member_with_permissions: { project => %i[view_work_packages save_queries] })
  end
  let(:query) do
    create(:query, user:, project:).tap do |q|
      q.add_filter(bool_cf.column_name.to_sym, "=", ["t"])
      q.save!
    end
  end

  it "shows the cf filter as invalid after change" do
    login_as(user)

    wp_table.visit!
    wp_table.visit_query(query)

    filters.open
    expect(page).to have_css("#filter_customField#{bool_cf.id}")
    expect(page).to have_css("#div-values-customField#{bool_cf.id}")

    # remove the is_filter from the custom field
    bool_cf.update!(is_filter: false)
    # reload the page with the query
    wp_table.visit_query(query)

    # expect the filter shown as invalid
    filters.open
    # The filter should still be rendered, but with a warning
    expect(page).to have_css("#filter_customField#{bool_cf.id} .advanced-filters--filter-value.--warning")
  end
end
