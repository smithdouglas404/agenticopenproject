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

module ResourceAllocations
  # A single allocation row in the work package allocations dialog: the member's
  # avatar and name (or an anonymous placeholder when the principal is not
  # visible to the current user) and the allocated hours.
  class ListItemComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers
    include AvatarHelper

    AVATAR_SIZE = 24

    def initialize(allocation:, visible:)
      super

      @allocation = allocation
      @visible = visible
    end

    private

    attr_reader :allocation

    def visible?
      @visible
    end

    def name
      if allocation.principal
        visible? ? allocation.principal.name : hidden_label
      else
        allocation.filter_name.presence || unassigned_label
      end
    end

    # Only a visible principal exposes a real avatar (and an identity-revealing
    # initials/colour seed). Everything else falls back to a generated avatar
    # keyed to the allocation, so a hidden user cannot be correlated.
    def avatar
      Primer::OpenProject::AvatarWithFallback.new(size: AVATAR_SIZE, **avatar_options)
    end

    def avatar_options
      if allocation.principal && visible?
        {
          src: avatar_url(allocation.principal),
          alt: allocation.principal.name,
          unique_id: allocation.principal.id
        }
      else
        {
          alt: name,
          unique_id: "resource-allocation-#{allocation.id}"
        }
      end
    end

    def hours
      t("resource_management.work_package_list.allocation.hours",
        value: helpers.number_with_precision(allocation.allocated_hours, precision: 1, strip_insignificant_zeros: true))
    end

    def hidden_label
      t("resource_management.work_package_allocations_dialog.hidden_user")
    end

    def unassigned_label
      t("resource_management.work_package_list.allocated_members.unassigned")
    end
  end
end
