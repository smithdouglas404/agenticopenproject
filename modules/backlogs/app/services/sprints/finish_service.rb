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

class Sprints::FinishService < BaseServices::BaseContracted
  def initialize(user:, model:)
    super(user:)
    self.model = model
  end

  protected

  def before_perform(service_call)
    if params[:move_to_sprint_id].present?
      @target_sprint = Agile::Sprint.find_by(id: params[:move_to_sprint_id])

      move_open_work_packages(@target_sprint).each do |result|
        service_call.add_dependent!(result)
      end
    end

    service_call
  end

  def persist(service_call)
    model.completed!
    service_call
  end

  def default_contract_class
    Sprints::FinishContract
  end

  private

  def move_open_work_packages(target_sprint)
    # TODO: Do this in order of the position
    # and reorder into the sprint in that same order
    # TODO: potentially do it with a different/no contract
    # so that it is possible to move work packages in all
    # projects the sprint is shared with.
    model.work_packages.with_status_open.map do |wp|
      WorkPackages::UpdateService.new(user:, model: wp).call(sprint: target_sprint)
    end
  end
end
