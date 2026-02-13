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

RSpec.describe OpenProject::InplaceEdit::UpdateRegistry do
  let(:handler) { instance_double(OpenProject::InplaceEdit::Handlers::ProjectUpdate) }
  let(:contract) { instance_double(Projects::UpdateContract) }

  before do
    described_class.instance_variable_set(:@registry, {})
  end

  after do
    described_class.instance_variable_set(:@registry, {})
  end

  describe ".register" do
    it "registers handler and contract for a model" do
      described_class.register(Project, handler:, contract:)

      expect(described_class.fetch_handler(Project.new)).to eq(handler)
      expect(described_class.fetch_contract(Project.new)).to eq(contract)
    end
  end

  describe ".registered?" do
    it "returns true for registered model" do
      described_class.register(Project, handler:, contract:)

      expect(described_class.registered?(Project)).to be(true)
    end

    it "returns false for unregistered model" do
      expect(described_class.registered?(Project)).to be(false)
    end
  end
end
