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

# SQL-based heuristic to filter journals with changes.
#
# Includes journals that have:
#   * Initial journal (version = 1) - always included
#   * Attachment changes (compares attachable_journals with predecessor)
#   * Custom field changes (compares customizable_journals with predecessor)
#   * File link changes (compares storages_file_links_journals with predecessor)
#   * Cause metadata (system-triggered changes)
#   * Attribute/data changes (compares work_package_journals columns with immediate predecessor)
#
# This heuristic compares association records with the predecessor journal to detect actual changes,
# not just the presence of snapshot records.
class WorkPackages::ActivitiesTab::Paginator::JournalChangesFilter
  class << self
    def apply(scope)
      sql = <<~SQL.squish
        version = 1
        OR (cause IS NOT NULL AND cause != '{}')
        OR EXISTS (#{attribute_data_changes_condition_sql})
        OR EXISTS (#{attachment_changes_condition_sql})
        OR EXISTS (#{custom_field_changes_condition_sql})
        OR EXISTS (#{file_link_changes_condition_sql})
      SQL

      scope.where(OpenProject::SqlSanitization.sanitize(sql))
    end

    private

    def attribute_data_changes_condition_sql
      <<~SQL.squish
        SELECT 1
          FROM journals predecessor
          INNER JOIN work_package_journals pred_data ON predecessor.data_id = pred_data.id
          INNER JOIN work_package_journals curr_data ON journals.data_id = curr_data.id
          WHERE predecessor.journable_id = journals.journable_id
            AND predecessor.journable_type = journals.journable_type
            AND predecessor.version = (#{max_predecessor_version_sql})
            AND (#{data_changes_condition_sql})
      SQL
    end

    def attachment_changes_condition_sql
      association_changes_condition_sql(
        table: Journal::AttachableJournal.table_name,
        id_column: "attachment_id",
        value_columns: ["filename"]
      )
    end

    def custom_field_changes_condition_sql
      association_changes_condition_sql(
        table: Journal::CustomizableJournal.table_name,
        id_column: "custom_field_id",
        value_columns: ["value"]
      )
    end

    def file_link_changes_condition_sql
      association_changes_condition_sql(
        table: Journal::StorableJournal.table_name,
        id_column: "file_link_id",
        value_columns: %w[link_name storage_name]
      )
    end

    # Identify the immediate predecessor journal for comparison.
    # NB: Journal versions are incremental but not guaranteed to be sequential.
    def max_predecessor_version_sql
      <<~SQL.squish
        SELECT MAX(version)
        FROM journals p2
        WHERE p2.journable_id = journals.journable_id
          AND p2.journable_type = journals.journable_type
          AND p2.version < journals.version
      SQL
    end

    def data_changes_condition_sql
      data_change_columns = Journal::WorkPackageJournal.column_names - ["id"]

      data_change_columns.map do |column_name|
        "pred_data.#{column_name} IS DISTINCT FROM curr_data.#{column_name}"
      end.join(" OR ")
    end

    # Detect changes in association journals by checking for additions or removals.
    def association_changes_condition_sql(table:, id_column:, value_columns:)
      "#{association_items_added_sql(table:, id_column:, value_columns:)} " \
        "UNION ALL " \
        "#{association_items_removed_sql(table:, id_column:)}"
    end

    # Detect added or modified association items by comparing with predecessor journal.
    # Returns SQL that finds items that either:
    # - Exist in current journal but not in predecessor (additions)
    # - Exist in both but have different values (modifications)
    def association_items_added_sql(table:, id_column:, value_columns:)
      value_changes = value_columns.map do |col|
        "pred.#{col} IS DISTINCT FROM curr.#{col}"
      end.join(" OR ")

      <<~SQL.squish
        SELECT 1
          FROM #{table} curr
          LEFT JOIN journals predecessor
            ON predecessor.journable_id = journals.journable_id
            AND predecessor.journable_type = journals.journable_type
            AND predecessor.version = (#{max_predecessor_version_sql})
          LEFT JOIN #{table} pred
            ON pred.journal_id = predecessor.id
            AND pred.#{id_column} = curr.#{id_column}
          WHERE curr.journal_id = journals.id
            AND (pred.id IS NULL OR (#{value_changes}))
      SQL
    end

    # Detect removed association items by comparing with predecessor journal.
    # Returns SQL that finds items that existed in predecessor but not in current journal.
    def association_items_removed_sql(table:, id_column:)
      <<~SQL.squish
        SELECT 1
          FROM journals predecessor
          INNER JOIN #{table} pred
            ON pred.journal_id = predecessor.id
          LEFT JOIN #{table} curr
            ON curr.journal_id = journals.id
            AND curr.#{id_column} = pred.#{id_column}
          WHERE predecessor.journable_id = journals.journable_id
            AND predecessor.journable_type = journals.journable_type
            AND predecessor.version = (#{max_predecessor_version_sql})
            AND curr.id IS NULL
      SQL
    end
  end
end
