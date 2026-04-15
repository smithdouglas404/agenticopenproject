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

RSpec.describe ProjectIdentifiers::RevertInstanceToClassicIdsJob do
  describe "#perform" do
    context "when there are projects to revert" do
      let!(:projects) { create_list(:project, 2) }

      it "calls RevertProjectToClassicService for each project" do
        services = projects.map do |project|
          instance_double(ProjectIdentifiers::RevertProjectToClassicService, call: nil).tap do |service|
            allow(ProjectIdentifiers::RevertProjectToClassicService).to receive(:new).with(project).and_return(service)
          end
        end

        described_class.new.perform

        services.each { |service| expect(service).to have_received(:call) }
      end
    end

    context "when there are no projects" do
      it "does not call RevertProjectToClassicService" do
        expect(ProjectIdentifiers::RevertProjectToClassicService).not_to receive(:new)
        described_class.new.perform
      end
    end
  end
end
