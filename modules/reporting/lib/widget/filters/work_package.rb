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

class Widget::Filters::WorkPackage < Widget::Filters::Base
  def render_filter
    div(id: "#{filter_class.underscore_name}_arg_1", class: "advanced-filters--filter-value") do
      selected_values = map_filter_values

      span(class: "inline-label") do
        html_label

        angular_component_tag "opce-autocompleter",
                              inputs: {
                                filters: [],
                                InputName: "values[#{filter_class.underscore_name}]",
                                hiddenFieldAction: "change->reporting--page#selectValueChanged",
                                multiple: true,
                                defaultData: true,
                                model: selected_values.compact,
                                url: ::API::V3::Utilities::PathHelper::ApiV3Path.work_packages,
                                resource: "work_packages",
                                searchKey: "subjectOrId"
                              },
                              id: "#{filter_class.underscore_name}_select_1",
                              class: "filter-value advanced-filters--ng-select"
      end
    end
  end

  private

  def html_label
    label for: "#{filter_class.underscore_name}_arg_1_val", class: "sr-only" do
      "#{filter_class.label} #{t(:label_filter_value)}"
    end
  end

  def map_filter_values
    expand_comma_separated_values!

    work_packages = WorkPackage.visible.where(id: filter.values)
    work_packages.map { |wp| { id: wp.id, name: wp.subject } }
  end
end
