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
require "contracts/shared/model_contract_shared_context"

RSpec.describe Sprints::CreateContract do
  include_context "ModelContract shared context"

  let(:project) { build_stubbed(:project) }
  let(:user) { build_stubbed(:user) }
  let(:sprint) do
    Agile::Sprint.new(name: sprint_name,
                      project:,
                      start_date: sprint_start_date,
                      finish_date: sprint_finish_date,
                      status: sprint_status)
  end
  let(:sprint_name) { "Sprint 1" }
  let(:sprint_start_date) { Time.zone.today }
  let(:sprint_finish_date) { Time.zone.today + 14.days }
  let(:sprint_status) { "in_planning" }
  let(:permissions) { [:create_sprints] }

  subject(:contract) { described_class.new(sprint, user) }

  before do
    mock_permissions_for(user) do |mock|
      mock.allow_in_project(*permissions, project:) if project
    end
  end

  describe "validation" do
    context "with valid attributes and permissions" do
      it_behaves_like "contract is valid"
    end

    context "when project is nil" do
      let(:project) { nil }

      it_behaves_like "contract is invalid", project: :blank
    end

    context "when user does not have create_sprints permission" do
      let(:permissions) { [:view_work_packages] }

      it_behaves_like "contract is invalid", base: :error_unauthorized
    end

    context "when user has no permissions in project" do
      let(:permissions) { [] }

      it_behaves_like "contract is invalid", base: :error_unauthorized
    end

    context "when name is blank" do
      let(:sprint_name) { "" }

      it_behaves_like "contract is invalid", name: :blank
    end

    context "when start_date is blank" do
      let(:sprint_start_date) { nil }

      it_behaves_like "contract is valid"
    end

    context "when finish_date is blank" do
      let(:sprint_finish_date) { nil }

      it_behaves_like "contract is valid"
    end

    context "when finish_date is before start_date" do
      let(:sprint_start_date) { Time.zone.today }
      let(:sprint_finish_date) { Time.zone.today - 1.day }

      it_behaves_like "contract is invalid", finish_date: %i[greater_than_or_equal_to]
    end

    context "when the sprint is active" do
      let(:sprint_status) { "active" }

      context "when start_date is blank" do
        let(:sprint_start_date) { nil }

        it_behaves_like "contract is invalid", start_date: :blank
      end

      context "when finish_date is blank" do
        let(:sprint_finish_date) { nil }

        it_behaves_like "contract is invalid", finish_date: :blank
      end

      context "when finish_date is before start_date" do
        let(:sprint_start_date) { Time.zone.today }
        let(:sprint_finish_date) { Time.zone.today - 1.day }

        it_behaves_like "contract is invalid", finish_date: %i[greater_than_or_equal_to]
      end
    end

    context "when user is admin without project permission" do
      let(:user) { build_stubbed(:admin) }
      let(:permissions) { [] }

      it_behaves_like "contract is valid"
    end
  end
end
