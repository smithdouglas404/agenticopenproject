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

# rubocop:disable Metrics/AbcSize
class Widget::Filters < Widget::Base
  include Phlex::Rails::Helpers::LabelTag
  include Phlex::Rails::Helpers::OptionsForSelect
  include Phlex::Rails::Helpers::SelectTag

  param :subject, reader: false

  attr_reader :engine

  def initialize(...)
    super

    @engine = @subject.class
  end

  def view_template
    ul id: "filter_table", class: "advanced-filters--filters" do
      render_filters

      li class: "advanced-filters--spacer hide-when-print"

      add_filter
    end
  end

  def selectables
    filters = engine::Filter.all
    filters.sort_by(&:label).select(&:selectable?).map do |filter|
      [filter.label, filter.underscore_name]
    end
  end

  def render_filters
    active_filters = @subject.filters.select(&:display?)
    engine::Filter.all.select(&:selectable?).map do |filter|
      opts = { id: "filter_#{filter.underscore_name}",
               class: "#{filter.underscore_name} advanced-filters--filter",
               "data-filter-name": filter.underscore_name }
      active_instance = active_filters.detect { |f| f.instance_of?(filter) }
      if active_instance
        opts[:"data-selected"] = true
      else
        opts[:style] = "display:none"
      end
      li(**opts) do
        render_filter filter, active_instance
      end
    end
  end

  # rubocop:disable Metrics/PerceivedComplexity
  def render_filter(f_cls, f_inst)
    f = f_inst || f_cls
    render Label.new(f)
    render Operators.new(f)

    # Handling for custom widgets first
    if f_cls == CostQuery::Filter::ProjectId
      render Project.new(f)
    elsif user_filter?(f_cls)
      render User.new(f)
    elsif f_cls == CostQuery::Filter::WorkPackageId
      render WorkPackage.new(f)
    # Handling of generic widgets
    elsif f_cls.heavy?
      render Heavy.new(f)
    elsif engine::Operator.string_operators.all? { |o| f_cls.available_operators.include? o }
      render TextBox.new(f)
    elsif engine::Operator.time_operators.all? { |o| f_cls.available_operators.include? o }
      render Date.new(f)
    elsif engine::Operator.integer_operators.all? { |o| f_cls.available_operators.include? o }
      if f_cls.available_values.blank?
        render TextBox.new(f)
      else
        render MultiValues.new(f, lazy: true)
      end
    elsif f_cls.is_multiple_choice?
      render MultiChoice.new(f)
    else
      render MultiValues.new(f, lazy: true)
    end
    render RemoveButton.new(f)
  end
  # rubocop:enable Metrics/PerceivedComplexity

  def add_filter
    li id: "add_filter_block", class: "advanced-filters--add-filter hide-when-print" do
      label(for: "add_filter_select", class: "advanced-filters--add-filter-label") do
        plain t(:label_filter_add)

        span(class: "sr-only") do
          plain t("js.filter.description.text_open_filter")
          whitespace
          plain t("js.filter.description.text_close_filter")
        end
      end

      div class: "advanced-filters--add-filter-value" do
        select_tag("add_filter_select",
                   class: "advanced-filters--select",
                   data: {
                     action: "reporting--page#addFilter"
                   },
                   name: nil) do
                     options_for_select([["", ""]] + selectables)
                   end
      end
    end
  end

  def user_filter?(f_cls)
    f_cls.in?([
                CostQuery::Filter::UserId,
                CostQuery::Filter::LoggedById,
                CostQuery::Filter::AssignedToId,
                CostQuery::Filter::ResponsibleId,
                CostQuery::Filter::AuthorId
              ])
  end
end
# rubocop:enable Metrics/AbcSize
