# frozen_string_literal: true

# -- copyright
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
# ++

require "spec_helper"

RSpec.describe UserQueries::SetAttributesService, type: :model do
  let(:current_user) { build_stubbed(:user) }
  let(:contract_instance) do
    contract = instance_double(UserQueries::CreateContract)
    allow(contract).to receive_messages(validate: contract_valid, errors: contract_errors)
    contract
  end
  let(:contract_errors) { instance_double(ActiveModel::Errors) }
  let(:contract_valid) { true }
  let(:model_instance) { UserQuery.new }
  let(:contract_class) do
    allow(UserQueries::CreateContract).to receive(:new).and_return(contract_instance)
    UserQueries::CreateContract
  end
  let(:instance) do
    described_class.new(user: current_user,
                        model: model_instance,
                        contract_class:,
                        contract_options: {})
  end

  before { allow(model_instance).to receive(:valid?).and_return(true) }

  subject { instance.call(params) }

  context "without params" do
    let(:params) { {} }

    it "is a success" do
      expect(subject).to be_success
    end

    it "sets the user by system" do
      subject
      expect(model_instance.user).to eq(current_user)
    end
  end

  context "with filter and order params" do
    let(:params) do
      {
        name: "Active admins",
        filters: [{ attribute: "status", operator: "=", values: ["active"] }],
        orders: [{ attribute: "id", direction: "desc" }]
      }
    end

    it "assigns the name" do
      subject
      expect(model_instance.name).to eq("Active admins")
    end

    it "assigns the filters" do
      subject
      expect(model_instance.filters.map { |f| [f.name, f.operator, f.values] })
        .to eql [[:status, "=", ["active"]]]
    end

    it "assigns the orders" do
      subject
      expect(model_instance.orders.map { |o| [o.name, o.direction] })
        .to eql [["id", :desc]]
    end
  end

  context "when replacing existing filters" do
    let(:model_instance) do
      UserQuery.new.tap { |q| q.where("status", "=", ["active"]) }
    end

    let(:params) do
      { filters: [{ attribute: "name", operator: "~", values: ["alice"] }] }
    end

    it "replaces existing filters" do
      subject
      expect(model_instance.filters.map(&:name)).to eql [:name]
    end
  end

  context "with an invalid contract" do
    let(:contract_valid) { false }
    let(:params) { {} }

    it "returns failure" do
      expect(subject).not_to be_success
    end
  end
end
