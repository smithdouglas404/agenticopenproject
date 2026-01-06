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

class Widget::Filters::Date < Widget::Filters::Base
  include Phlex::Rails::Helpers::TextFieldTag

  def render_filter # rubocop:disable Metrics/AbcSize
    name = "values[#{filter_class.underscore_name}][]"
    id_prefix = "#{filter_class.underscore_name}_"

    span class: "advanced-filters--filter-value -binary" do
      span id: "#{id_prefix}arg_1" do
        label(for: "#{id_prefix}arg_1_val", class: "sr-only") { value_label }

        angular_component_tag "opce-basic-single-date-picker",
                              inputs: {
                                value: filter.operator.forced == :integers ? "" : filter.values.first.to_s,
                                id: "#{id_prefix}arg_1_val",
                                name:
                              }
      end

      span id: "#{id_prefix}arg_2", class: "advanced-filters--filter-value2" do
        label(for: "#{id_prefix}arg_2_val", class: "sr-only") { value_label }

        angular_component_tag "opce-basic-single-date-picker",
                              inputs: {
                                value: filter.operator.forced == :integers ? "" : filter.values.second.to_s,
                                id: "#{id_prefix}arg_2_val",
                                name: name.to_s
                              }
      end

      span id: "#{id_prefix}arg_1_integers", class: "advanced-filters--integer" do
        label(for: "#{id_prefix}arg_1_integers_val", class: "sr-only") { value_label }

        text_field_tag(name,
                       filter.operator.forced == :integers ? filter.values.first.to_s : "",
                       type: "number",
                       min: 0,
                       steps: 1,
                       class: "advanced-filters--text-field -slim",
                       id: "#{id_prefix}arg_1_integers_val",
                       "data-filter-name": filter_class.underscore_name)
      end
    end
  end

  def value_label
    "#{filter_class.label} #{t(:label_filter_value)}"
  end
end
