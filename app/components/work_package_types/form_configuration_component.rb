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

module WorkPackageTypes
  class FormConfigurationComponent < ApplicationComponent
    include OpTurbo::Streamable
    include OpPrimer::ComponentHelpers

    ENTERPRISE_DIALOG_ID = "type-form-configuration-enterprise-dialog"
    ENTERPRISE_INFORMATION_URL = "https://www.openproject.org/enterprise-edition/?utm_source=unknown&utm_medium=community-edition&utm_campaign=form-configuration"

    def initialize(type:, form_attributes:, no_filter_query:)
      super(type)
      @type = type
      @groups = form_attributes[:actives].reject { |g| g[:key].to_s == "__empty" }
      @inactives = form_attributes[:inactives]
      @no_filter_query = no_filter_query
    end

    def ee_available?
      EnterpriseToken.allows_to?(:edit_attribute_groups)
    end

    def enterprise_dialog_id
      ENTERPRISE_DIALOG_ID
    end

    def enterprise_information_url
      ENTERPRISE_INFORMATION_URL
    end

    def section_components
      @groups.map.with_index do |group, i|
        WorkPackageTypes::FormConfiguration::SectionComponent.new(
          group:,
          type: @type,
          ee_available: ee_available?,
          first: i == 0,
          last: i == @groups.length - 1
        )
      end
    end
  end
end
