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

RSpec.describe API::V3::Backlogs::BacklogRepresenter do
  let(:type) { build_stubbed(:type, color: build_stubbed(:color)) }
  let(:representer) { described_class.new(type, current_user: double("current_user")) }

  include API::V3::Utilities::PathHelper

  context "generation" do
    subject { representer.to_json }

    describe "links" do
      it_behaves_like "has a titled link" do
        let(:link) { "self" }
        let(:href) { api_v3_paths.type(type.id) }
        let(:title) { type.name }
      end
    end

    it "indicates its id" do
      expect(subject).to be_json_eql(type.id.to_json).at_path("id")
    end

    it "indicates its name" do
      expect(subject).to be_json_eql(type.name.to_json).at_path("name")
    end

    it "indicates its color" do
      expect(subject).to be_json_eql(type.color.hexcode.to_json).at_path("color")
    end
  end
end
