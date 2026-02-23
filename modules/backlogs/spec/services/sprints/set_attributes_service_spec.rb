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

RSpec.describe Sprints::SetAttributesService, type: :model do
  let(:user) { build_stubbed(:user) }
  let(:contract_class) do
    contract = class_double(Sprints::CreateContract)

    allow(contract)
      .to receive(:new)
      .with(sprint, user, options: {})
      .and_return(contract_instance)

    contract
  end
  let(:contract_instance) do
    instance_double(ModelContract, validate: contract_valid, errors: contract_errors)
  end
  let(:contract_valid) { true }
  let(:contract_errors) do
    instance_double(ActiveModel::Errors)
  end
  let(:sprint_valid) { true }
  let(:instance) do
    described_class.new(user:,
                        model: sprint,
                        contract_class:,
                        contract_options: {})
  end
  let(:sprint) { build_stubbed(:agile_sprint) }
  let(:params) { {} }

  subject(:service_call) { instance.call(params) }

  describe "call" do
    before do
      allow(sprint)
        .to receive(:valid?)
        .and_return(sprint_valid)

      allow(sprint).to receive(:save)
    end

    context "when contract validates and sprint is valid" do
      it "is successful" do
        expect(service_call).to be_success
      end

      it "sets the attributes on the sprint" do
        service_call

        expect(sprint.changed_attributes).to be_empty
      end

      it "does not persist the sprint" do
        expect(sprint).not_to have_received(:save)

        service_call
      end
    end

    context "when contract does not validate" do
      let(:contract_valid) { false }

      it "is not successful" do
        expect(service_call).not_to be_success
      end
    end

    context "with params" do
      let(:params) do
        {
          name: "New Sprint Name",
          start_date: Time.zone.today,
          finish_date: Time.zone.today + 21.days,
          status: "active"
        }
      end

      before do
        allow(contract_instance)
          .to receive(:validate)
          .and_return(true)
      end

      it "passes the params to the sprint" do
        service_call

        expect(sprint.name).to eq("New Sprint Name")
        expect(sprint.start_date).to eq(Time.zone.today)
        expect(sprint.finish_date).to eq(Time.zone.today + 21.days)
        expect(sprint.status).to eq("active")
      end
    end

    describe "default attributes" do
      let(:sprint) { Agile::Sprint.new }

      it "sets default status to in_planning" do
        service_call

        expect(sprint.status).to eq("in_planning")
      end

      it "sets default sharing to none" do
        service_call

        expect(sprint.sharing).to eq("none")
      end

      context "when status is already set" do
        let(:sprint) { Agile::Sprint.new(status: "active") }

        it "does not override the existing status" do
          service_call

          expect(sprint.status).to eq("active")
        end
      end

      context "when sharing is already set" do
        let(:sprint) { Agile::Sprint.new(sharing: "descendants") }

        it "does not override the existing sharing" do
          service_call

          expect(sprint.sharing).to eq("descendants")
        end
      end
    end
  end
end
