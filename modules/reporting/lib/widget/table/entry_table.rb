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

class Widget::Table::EntryTable < Widget::Table
  FIELDS = %i[user_id activity_id entity_gid comments logged_by_id project_id].freeze

  def view_template
    div class: "generic-table--container -with-footer" do
      div class: "generic-table--results-container" do
        table class: "generic-table", id: "sortable-table", data: { reporting__page_target: "table" } do
          render_colgroup

          head
          foot
          body
        end
      end
    end
  end

  def render_colgroup
    colgroup do
      col
      FIELDS.each do
        col
      end
      col
      col
      col
    end
  end

  def head_column_field(field)
    head_column(label_for(field))
  end

  def head_column(label)
    th do
      div(class: "generic-table--sort-header-outer") do
        div(class: "generic-table--sort-header") do
          span(label)
        end
      end
    end
  end

  # rubocop:disable Metrics/AbcSize
  def head
    thead do
      tr do
        head_column_field(:spent_on)
        head_column(t("label_time")) if with_times_column?
        FIELDS.map do |field|
          head_column_field(field)
        end
        head_column(cost_type.try(:unit_plural) || t(:units))
        head_column(CostEntry.human_attribute_name(:costs))
        hit = false
        @subject.each_direct_result do |result|
          next if hit

          if entry_for(result).editable_by? User.current
            th(class: "unsortable") do
              div("", class: "generic-table--empty-header")
            end
            hit = true
          end
        end
      end
    end
  end

  def foot
    tfoot do
      tr do
        main_columns = with_times_column? ? 2 : 1
        if show_result(@subject, 0) == show_result(@subject)
          td(colspan: FIELDS.size + main_columns + 1)
          td do
            div(
              show_result(@subject),
              class: "result generic-table--footer-outer"
            )
          end
        else
          td(colspan: FIELDS.size + main_columns)
          td do
            div(
              show_result(@subject),
              class: "inner generic-table--footer-outer"
            )
          end
          td do
            div(
              show_result(@subject, 0),
              class: "result generic-table--footer-outer"
            )
          end
        end
        th(class: "unsortable")
      end
    end
  end

  def body_column_field(field, result)
    td(show_field(field, result.fields[field.to_s]),
       "raw-data": raw_field(field, result.fields[field.to_s]),
       class: "left")
  end

  def body
    tbody do
      rows = "".html_safe
      @subject.each_direct_result do |result|
        rows << (tr do
          body_column_field(:spent_on, result)
          if with_times_column?
            td spent_on_time_representation(result.start_timestamp, result["units"].to_f),
               class: "start_time right",
               "raw-data": result.start_timestamp.to_s
          end
          FIELDS.each do |field|
            body_column_field(field, result)
          end
          td show_result(result, result.fields["cost_type_id"].to_i),
             class: "units right",
             "raw-data": result.units
          td  show_result(result, 0),
              class: "currency right",
              "raw-data": result.real_costs
          td icons(result)
        end)
      end
      rows
    end
  end

  def icons(result)
    icons = ""
    with_project(result.fields["project_id"]) do
      if entry_for(result).editable_by? User.current
        if controller_for(result.fields["type"]) == "costlog"
          # icons = link_to(icon_wrapper("icon-context icon-edit", t(:button_edit)),
          #                action_for(result, action: "edit"),
          #                class: "no-decoration-on-hover",
          #                title: t(:button_edit))

          # icons << link_to(icon_wrapper("icon-context icon-delete", t(:button_delete)),
          #                 action_for(result, action: "destroy")
          #                   .reverse_merge(authenticity_token: form_authenticity_token),
          #                 data: { turbo_method: :delete, turbo_confirm: t(:text_are_you_sure) },
          #                 class: "no-decoration-on-hover",
          #                 title: t(:button_delete))
        else
          icons = angular_component_tag("opce-time-entry-trigger-actions",
                                        data: { entry: result["id"] })
        end
      end
    end
    icons
  end

  # rubocop:enable Metrics/AbcSize

  def labour_query?
    cost_type_filter = @subject.filters.detect { |f| f.is_a?(CostQuery::Filter::CostTypeId) }
    cost_type_filter&.values&.first.to_i == -1
  end

  def with_times_column?
    Setting.allow_tracking_start_and_end_times && labour_query?
  end
end
