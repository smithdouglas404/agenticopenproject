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

RSpec.describe "ResourceAllocations requests",
               :skip_csrf,
               type: :rails_request do
  shared_let(:project) { create(:project, enabled_module_names: %w[resource_management work_package_tracking]) }
  shared_let(:user) do
    create(:user,
           member_with_permissions: { project => %i[view_resource_planners allocate_user_resources view_work_packages] })
  end
  shared_let(:assignee) { create(:user, member_with_permissions: { project => %i[view_work_packages] }) }
  shared_let(:work_package) { create(:work_package, project:) }

  before { login_as user }

  describe "GET new" do
    it "opens the dialog on the kind-selection step" do
      get new_project_resource_allocation_path(project), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="principal"')
      expect(response.body).to include('value="filter"')
    end
  end

  describe "GET step" do
    context "with allocation_kind=principal" do
      it "renders the allocation step with a user picker" do
        get step_project_resource_allocations_path(project, allocation_kind: "principal"), as: :turbo_stream

        expect(response).to have_http_status(:ok)
        # Autocompleters render as Angular custom elements carrying the field
        # name in `data-input-name` rather than a plain `name` attribute.
        expect(response.body).to include("opce-user-autocompleter")
        expect(response.body).to include("resource_allocation[principal_id]")
        expect(response.body).to include("resource_allocation[entity_id]")
        expect(response.body).to include("resource_allocation[allocated_hours]")
      end
    end

    context "with allocation_kind=filter" do
      it "renders the allocation step with a filter name and the filter form" do
        get step_project_resource_allocations_path(project, allocation_kind: "filter"), as: :turbo_stream

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("resource_allocation[filter_name]")
        expect(response.body).to include('name="filters"')
      end
    end
  end

  describe "POST create" do
    context "for an explicit user" do
      subject(:perform) do
        post project_resource_allocations_path(project),
             params: {
               allocation_kind: "principal",
               resource_allocation: {
                 principal_id: assignee.id,
                 entity_type: "WorkPackage",
                 entity_id: work_package.id,
                 start_date: "2026-03-02",
                 end_date: "2026-03-03",
                 allocated_hours: "40h"
               }
             },
             as: :turbo_stream
      end

      it "creates a resource allocation for the principal" do
        expect { perform }.to change(ResourceAllocation, :count).by(1)

        allocation = ResourceAllocation.last
        expect(allocation.entity).to eq(work_package)
        expect(allocation.principal).to eq(assignee)
        expect(allocation).to be_principal_explicit
        expect(allocation.allocated_time).to eq(40 * 60)
        expect(allocation.filter_name).to be_nil
        expect(allocation.user_filter).to eq([])
        expect(allocation.requested_by).to eq(user)
      end
    end

    context "for a filter-criteria placeholder" do
      subject(:perform) do
        post project_resource_allocations_path(project),
             params: {
               allocation_kind: "filter",
               filters: [{ login: { operator: "~", values: ["dev"] } }].to_json,
               resource_allocation: {
                 filter_name: "Full stack Developer (DE-EN)",
                 entity_type: "WorkPackage",
                 entity_id: work_package.id,
                 start_date: "2026-03-02",
                 end_date: "2026-03-03",
                 allocated_hours: "40h"
               }
             },
             as: :turbo_stream
      end

      it "creates a placeholder allocation carrying the user filter" do
        expect { perform }.to change(ResourceAllocation, :count).by(1)

        allocation = ResourceAllocation.last
        expect(allocation.principal).to be_nil
        expect(allocation).not_to be_principal_explicit
        expect(allocation).to be_needs_principal_assignment
        expect(allocation.filter_name).to eq("Full stack Developer (DE-EN)")
        expect(allocation.user_filter.map(&:name)).to contain_exactly(:login)
        expect(allocation.user_filter.first.values).to eq(["dev"])
      end
    end

    context "with invalid input" do
      subject(:perform) do
        post project_resource_allocations_path(project),
             params: {
               allocation_kind: "principal",
               resource_allocation: {
                 principal_id: assignee.id,
                 entity_type: "WorkPackage",
                 entity_id: work_package.id,
                 start_date: "2026-03-03",
                 end_date: "2026-03-02", # before start_date
                 allocated_hours: "40h"
               }
             },
             as: :turbo_stream
      end

      it "does not create an allocation and re-renders the step" do
        expect { perform }.not_to change(ResourceAllocation, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with a work package the user cannot reach in this project" do
      shared_let(:other_work_package) { create(:work_package) }

      subject(:perform) do
        post project_resource_allocations_path(project),
             params: {
               allocation_kind: "principal",
               resource_allocation: {
                 principal_id: assignee.id,
                 entity_type: "WorkPackage",
                 entity_id: other_work_package.id,
                 start_date: "2026-03-02",
                 end_date: "2026-03-03",
                 allocated_hours: "40h"
               }
             },
             as: :turbo_stream
      end

      it "does not create an allocation and re-renders the step" do
        expect { perform }.not_to change(ResourceAllocation, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with an entity type outside the allow-list" do
      subject(:perform) do
        post project_resource_allocations_path(project),
             params: {
               allocation_kind: "principal",
               resource_allocation: {
                 principal_id: assignee.id,
                 entity_type: "Project",
                 entity_id: project.id,
                 start_date: "2026-03-02",
                 end_date: "2026-03-03",
                 allocated_hours: "40h"
               }
             },
             as: :turbo_stream
      end

      it "does not create an allocation and re-renders the step" do
        expect { perform }.not_to change(ResourceAllocation, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when the allocation dates fall outside the work package's dates" do
      shared_let(:dated_work_package) do
        create(:work_package, project:, start_date: Date.new(2026, 1, 15), due_date: Date.new(2026, 2, 20))
      end

      let(:base_params) do
        {
          allocation_kind: "principal",
          resource_allocation: {
            principal_id: assignee.id,
            entity_type: "WorkPackage",
            entity_id: dated_work_package.id,
            start_date: "2026-02-24", # after the work package's finish date
            end_date: "2026-02-25",
            allocated_hours: "40h"
          }
        }
      end

      it "does not create yet and renders the confirmation step" do
        expect do
          post project_resource_allocations_path(project), params: base_params, as: :turbo_stream
        end.not_to change(ResourceAllocation, :count)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("outside of the work")
        expect(response.body).to include('name="confirmed"')
      end

      it "creates the allocation once confirmed" do
        expect do
          post project_resource_allocations_path(project),
               params: base_params.merge(confirmed: "1"),
               as: :turbo_stream
        end.to change(ResourceAllocation, :count).by(1)

        expect(ResourceAllocation.last.entity).to eq(dated_work_package)
      end

      it "returns to the editable step without creating when going back" do
        expect do
          post project_resource_allocations_path(project),
               params: base_params.merge(back: "1"),
               as: :turbo_stream
        end.not_to change(ResourceAllocation, :count)

        expect(response).to have_http_status(:ok)
        # The editable step re-renders the user autocompleter.
        expect(response.body).to include("opce-user-autocompleter")
      end
    end

    context "when the allocation dates fall within the work package's dates" do
      shared_let(:dated_work_package) do
        create(:work_package, project:, start_date: Date.new(2026, 1, 15), due_date: Date.new(2026, 2, 20))
      end

      it "creates the allocation directly without confirmation" do
        expect do
          post project_resource_allocations_path(project),
               params: {
                 allocation_kind: "principal",
                 resource_allocation: {
                   principal_id: assignee.id,
                   entity_type: "WorkPackage",
                   entity_id: dated_work_package.id,
                   start_date: "2026-01-20",
                   end_date: "2026-01-21",
                   allocated_hours: "40h"
                 }
               },
               as: :turbo_stream
        end.to change(ResourceAllocation, :count).by(1)
      end
    end
  end

  context "without the allocate_user_resources permission" do
    shared_let(:viewer) { create(:user, member_with_permissions: { project => %i[view_resource_planners] }) }

    before { login_as viewer }

    it "denies access to the new dialog" do
      get new_project_resource_allocation_path(project), as: :turbo_stream

      expect(response).to have_http_status(:forbidden)
    end
  end
end
