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
# ++

module OpPrimer
  module QuickFilter
    class SelectPanelComponent < ApplicationComponent
      include ApplicationHelper

      renders_many :items, OpPrimer::QuickFilter::Item

      def initialize(name:, query:, filter_key:, path_args:, operator: "=")
        super

        @name = name
        @query = query
        @filter_key = filter_key
        @path_args = path_args
        @operator = operator
      end

      def render?
        items.any?
      end

      private

      def current_values
        @query.find_active_filter(@filter_key)&.values&.map(&:to_s) || []
      end

      def current_label
        return @name if current_values.empty?

        selected = items.select { |item| current_values.include?(item.value.to_s) }
        return @name if selected.empty?

        return selected.first.label if selected.size == 1

        I18n.t(:label_x_items_selected, count: selected.size)
      end

      def base_url
        polymorphic_path(@path_args, base_url_params)
      end

      def base_url_params
        {}.tap do |params|
          params[:filters] = other_filters.to_json if other_filters.any?
          params[:sortBy] = sort.to_json if sort.any?
        end
      end

      def other_filters
        @query.filters
          .reject { |f| f.name == @filter_key }
          .map { |f| { f.class.key.to_s => { "operator" => f.operator.to_s, "values" => f.values } } }
      end

      def sort
        @query.orders.map { |order| [order.name, order.direction.to_s] }
      end
    end
  end
end
