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
require_relative "../../support/pages/backlog"

RSpec.describe "Backlog bucket display",
               :js,
               with_flag: { backlog_buckets: true } do
  create_shared_association_defaults_for_work_package_factory

  shared_let(:project) do
    create(:project, enabled_module_names: %w[work_package_tracking backlogs])
  end

  shared_let(:bucket_beta) { create(:backlog_bucket, project:, name: "Beta bucket") }
  shared_let(:bucket_alpha) { create(:backlog_bucket, project:, name: "Alpha bucket") }
  shared_let(:bucket_gamma) { create(:backlog_bucket, project:, name: "Gamma bucket") }

  shared_let(:wp_alpha1) { create(:work_package, project:, backlog_bucket: bucket_alpha, position: 1) }
  shared_let(:wp_alpha2) { create(:work_package, project:, backlog_bucket: bucket_alpha, position: 2) }
  shared_let(:wp_beta1)  { create(:work_package, project:, backlog_bucket: bucket_beta,  position: 1) }
  shared_let(:wp_inbox1) { create(:work_package, project:, backlog_bucket: nil, sprint: nil, position: 1) }

  let(:backlogs_page) { Pages::Backlog.new(project) }

  current_user do
    create(:user,
           member_with_permissions: {
             project => %i[view_sprints view_work_packages create_sprints manage_sprint_items]
           })
  end

  it "lists buckets alphabetically (inbox at the bottom is not named)" do
    backlogs_page.visit!

    backlogs_page.expect_bucket_names_in_order(
      "Alpha bucket",
      "Beta bucket",
      "Gamma bucket"
    )
  end

  it "shows the work-package count on populated buckets" do
    backlogs_page.visit!

    backlogs_page.expect_backlog_bucket_work_package_count(bucket_alpha, 2)
    backlogs_page.expect_backlog_bucket_work_package_count(bucket_beta, 1)
  end

  it "shows the '+ Backlog Bucket' button" do
    backlogs_page.visit!

    backlogs_page.expect_new_backlog_bucket_button
  end

  context "when the feature flag is disabled", with_flag: { backlog_buckets: false } do
    it "shows the legacy inbox instead of backlog buckets" do
      backlogs_page.visit!

      backlogs_page.expect_no_new_backlog_bucket_button
      backlogs_page.expect_no_backlog_bucket(bucket_alpha)
      expect(page).to have_css("#inbox_#{project.id}")
    end
  end

  context "without the :create_sprints permission" do
    current_user do
      create(:user,
             member_with_permissions: {
               project => %i[view_sprints view_work_packages manage_sprint_items]
             })
    end

    it "hides the '+ Backlog Bucket' button" do
      backlogs_page.visit!

      backlogs_page.expect_no_new_backlog_bucket_button
    end
  end
end
