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

RSpec.describe "Work packages identifier settings",
               :skip_csrf,
               type: :rails_request do
  let(:admin) { create(:admin) }

  before do
    with_flags(semantic_work_package_ids: true)
    login_as(admin)
  end

  describe "PATCH /admin/settings/work_packages_identifier" do
    context "when confirm_dangerous_action is set (user confirmed the migration dialog)" do
      it "enqueues a ConvertInstanceToSemanticIdsJob and redirects" do
        allow(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).to receive(:perform_later)

        patch "/admin/settings/work_packages_identifier",
              params: { settings: {}, confirm_dangerous_action: "1" }

        expect(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).to have_received(:perform_later)
        expect(response).to redirect_to(admin_settings_work_packages_identifier_path)
      end
    end

    context "when confirm_dangerous_action is not set (plain settings save)" do
      it "does not enqueue a migration job" do
        allow(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).to receive(:perform_later)

        patch "/admin/settings/work_packages_identifier",
              params: { settings: { work_packages_identifier: "classic" } }

        expect(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).not_to have_received(:perform_later)
      end
    end
  end
end
