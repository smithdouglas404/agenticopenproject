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
#
module CustomFields
  class DetailsComponent < ApplicationComponent
    include ApplicationHelper
    include EnterpriseHelper
    include OpPrimer::ComponentHelpers
    include OpTurbo::Streamable

    alias_method :custom_field, :model

    def persisted_cf_has_no_items_or_projects?
      custom_field.persisted? &&
        custom_field.hierarchical_list? &&
        custom_field.hierarchy_root.children.empty? &&
        custom_field.projects.empty?
    end

    def form_url
      model.new_record? ? custom_fields_path : custom_field_path(model)
    end

    def form_method
      model.new_record? ? :post : :put
    end

    def enterprise_addon
      @enterprise_addon ||= case custom_field.field_format
                            when "hierarchy"
                              { key: :custom_field_hierarchies, image: "enterprise/hierarchies.png" }
                            when "weighted_item_list"
                              { key: :weighted_item_lists, image: "enterprise/weighted_item_lists.png" }
                            else
                              raise "Custom fields of format #{custom_field.field_format} are not supported by #{self.class.name}"
                            end
    end
  end
end
