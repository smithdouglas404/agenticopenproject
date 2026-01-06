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

class Widget::GroupBys < Widget::Base
  include Phlex::Rails::Helpers::LabelTag

  param :subject, reader: false

  attr_reader :engine

  def initialize(...)
    super

    @engine = @subject.class
  end

  def view_template
    div(id: "group-by--area", class: "autoscroll") do
      render_group("columns", @subject.group_bys(:column))
      render_group("rows", @subject.group_bys(:row))
    end
  end

  # rubocop:disable Metrics/AbcSize
  def render_options(group_by_ary)
    group_by_ary.sort_by(&:label).each do |group_by|
      next unless group_by.selectable?

      label_text = group_by.label
      option_tags = { value: group_by.underscore_name, "data-label": label_text }
      option_tags[:title] = label_text if label_text.length > 40
      option(**option_tags) do
        truncate_single_line(label_text, length: 40)
      end
    end
  end

  def render_group(type, initially_selected)
    initially_selected = initially_selected.map do |group_by|
      [group_by.class.underscore_name, group_by.class.label]
    end

    fieldset do
      legend(class: "sr-only") { t("reporting.group_by.selected_#{type}") }

      div id: "group-by--#{type}", class: "group-by--container grid-block",
          "data-initially-selected": initially_selected.to_json.tr('"', "'") do
        span class: "group-by--caption grid-content shrink" do
          span do
            t(:"label_#{type}")
          end
        end

        span id: "group-by--selected-#{type}", class: "group-by--selected-elements grid-block"

        span class: "group-by--control grid-content shrink" do
          label for: "group-by--add-#{type}", class: "sr-only" do
            "#{t(:label_group_by_add)} #{t('js.filter.description.text_open_filter')}"
          end

          select(
            id: "group-by--add-#{type}",
            class: "advanced-filters--select",
            data: {
              action: "change->reporting--page#addGroupBy"
            }
          ) do
            option(value: "", disabled: true, selected: true) { t(:label_group_by_add) }

            engine::GroupBy.all_grouped.sort_by do |i18n_key, _group_by_ary|
              t(i18n_key)
            end.map do |i18n_key, group_by_ary| # rubocop:disable Style/MultilineBlockChain
              optgroup label: t(i18n_key) do
                render_options group_by_ary
              end
            end
          end
        end
      end
    end
  end
  # rubocop:enable Metrics/AbcSize
end
