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

      def initialize(name:, query:, filter_key:, path_args:, operator: "=", src: nil, label_method: :name)
        super

        @name = name
        @query = query
        @filter_key = filter_key
        @path_args = path_args
        @operator = operator
        @src = src
        @label_method = label_method
      end

      def before_render
        if async? && local?
          raise ArgumentError, "Use `src` for async loading or inline items for local rendering, not both."
        end

        if async? &&
           @query.filter_for(@filter_key).method(:value_objects).owner == Queries::Filters::Base
          raise ArgumentError,
                "#{@query.filter_for(@filter_key).class} does not implement #value_objects. " \
                "This is required when using the async version."
        end
      end

      def render?
        async? || local?
      end

      private

      def async?
        @src.present?
      end

      def local?
        items.any?
      end

      def active_filter
        @active_filter ||= @query.find_active_filter(@filter_key)
      end

      def current_values
        active_filter&.values&.map(&:to_s) || []
      end

      def current_label
        return @name if current_values.empty?
        return I18n.t(:label_x_items_selected, count: current_values.size) if current_values.size > 1

        single_label || @name
      end

      def single_label
        if async?
          active_filter.value_objects.first.send(@label_method)
        elsif local?
          items.find { |item| current_values.include?(item.value.to_s) }.label
        end
      end

      def panel_src
        return unless async?
        # Pass currently selected ids so the right items can be marked in the response
        return @src if current_values.empty?

        uri = URI.parse(@src)
        uri.query = Rack::Utils.parse_nested_query(uri.query.to_s)
                               .merge("selected" => current_values.join(","))
                               .to_query
        uri.to_s
      end

      def fetch_strategy
        async? ? :eventually_local : :local
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
