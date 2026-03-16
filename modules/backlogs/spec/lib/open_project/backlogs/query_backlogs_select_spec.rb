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

RSpec.describe OpenProject::Backlogs::QueryBacklogsSelect do
  describe ".instances" do
    subject(:attribute_names) { described_class.instances(context).map(&:name) }

    context "without context" do
      let(:context) { nil }

      it "returns all backlogs selects" do
        expect(attribute_names).to contain_exactly(:story_points, :position)
      end
    end

    context "when backlogs is enabled" do
      let(:context) { instance_double(Project, backlogs_enabled?: true) }

      it "returns all backlogs selects" do
        expect(attribute_names).to contain_exactly(:story_points, :position)
      end
    end

    context "when backlogs is disabled" do
      let(:context) { instance_double(Project, backlogs_enabled?: false) }

      it "returns only story points" do
        expect(attribute_names).to contain_exactly(:story_points)
      end
    end
  end
end
