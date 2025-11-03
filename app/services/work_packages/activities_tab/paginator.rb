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

# Paginates work package activities (journals and changesets) with support for filtering and anchor navigation.
#
# Filter modes:
# - :all - Shows all activities (default)
# - :only_comments - Shows only journals with notes
# - :only_changes - Shows only journals with detected changes using SQL heuristics
#
# Anchor format (filter is reset to :all when using anchors):
# - "comment-{journal_id}" - Navigate to specific journal by ID
# - "activity-{sequence_version}" - Navigate to journal by sequence version
#
# @param work_package [WorkPackage] The work package to paginate activities for
# @param params [Hash] Pagination and filtering parameters
#
# @option params [Integer] :page Page number (default: 1)
# @option params [Integer] :limit Records per page (default: Pagy::DEFAULT[:limit])
# @option params [Symbol] :filter Filter mode (:all, :only_comments, :only_changes)
# @option params [String] :anchor Anchor to navigate to specific journal
#
# @return [Array<Pagy, Array>] Pagy pagination object and array of activity records
class WorkPackages::ActivitiesTab::Paginator
  include Pagy::Backend
  include WorkPackages::ActivitiesTab::JournalSortingInquirable

  def self.paginate(work_package, params = {})
    new(work_package, params).call
  end

  attr_reader :work_package, :params, :filter

  def initialize(work_package, params = {})
    @work_package = work_package
    @params = params
    @filter = params[:filter]&.to_sym || :all
  end

  def call
    anchor_type, target_record_id = extract_target_record_id

    pagy, records =
      if anchor_type && target_record_id
        @filter = :all # Ignore filter when jumping to specific journal
        pagy_array_for_target_journal(anchor_type, target_record_id)
      else
        pagy_array(base_journals, **pagy_options)
      end

    # For UI display: if user wants "oldest first" UI, reverse the array
    records = records.reverse if journal_sorting.asc?

    [pagy, records]
  end

  private

  def pagy_options
    { page: params[:page] || 1, limit: params[:limit] || Pagy::DEFAULT[:limit], max_pages: 100 }.compact
  end

  def extract_target_record_id
    anchor = params[:anchor] # e.g., "comment-78758" (without #)
    return nil unless anchor

    match = anchor.match(/^(comment|activity)-(\d+)$/)
    match && match.length == 3 ? [match[1].inquiry, match[2].to_i] : []
  end

  def pagy_array_for_target_journal(anchor_type, target_record_id)
    journals = base_journals

    target_index = journals.find_index do |record|
      if anchor_type.comment?
        record.id == target_record_id
      elsif anchor_type.activity?
        record.sequence_version == target_record_id
      else
        false
      end
    end

    if target_index
      limit = pagy_options[:limit]
      target_page = (target_index / limit) + 1
      pagy_array(journals, **pagy_options, page: target_page)
    else
      # Journal might be filtered out or deleted - fallback to page 1
      pagy_array(journals, **pagy_options, page: 1)
    end
  end

  def base_journals
    combine_and_sort_records(fetch_journals, fetch_revisions)
  end

  def fetch_journals
    API::V3::Activities::ActivityEagerLoadingWrapper.wrap(fetch_ar_journals)
  end

  def fetch_ar_journals
    journals = work_package
      .journals
      .internal_visible
      .includes(
        :user,
        :customizable_journals,
        :attachable_journals,
        :storable_journals,
        :notifications
      )
      .reorder(version: :desc) # Always fetch newest first for pagination
      .with_sequence_version

    journals = journals.where.not(notes: [nil, ""]) if filter == :only_comments
    journals = apply_only_changes_filter_heuristic(journals) if filter == :only_changes

    journals
  end

  def fetch_revisions
    return Changeset.none if filter == :only_comments

    work_package.changesets.includes(:user, :repository)
  end

  def combine_and_sort_records(journals, revisions)
    (journals + revisions).sort_by do |record|
      timestamp = record_timestamp(record)
      [-timestamp, -record.id] # Always sort DESC (newest first)
    end
  end

  def record_timestamp(record)
    if record.is_a?(API::V3::Activities::ActivityEagerLoadingWrapper)
      record.created_at&.to_i
    elsif record.is_a?(Changeset)
      record.committed_on.to_i
    end
  end

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
  def apply_only_changes_filter_heuristic(journals)
    sql = <<~SQL.squish
      version = 1
      OR (cause IS NOT NULL AND cause != '{}')
      OR EXISTS (#{attribute_data_changes_condition_sql})
      OR EXISTS (#{attachment_changes_condition_sql})
      OR EXISTS (#{custom_field_changes_condition_sql})
      OR EXISTS (#{file_link_changes_condition_sql})
    SQL

    journals.where(OpenProject::SqlSanitization.sanitize(sql))
  end

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

  # Detect changes in work_package_journals columns.
  def data_changes_condition_sql
    data_change_columns.map do |column_name|
      "pred_data.#{column_name} IS DISTINCT FROM curr_data.#{column_name}"
    end.join(" OR ")
  end

  def data_change_columns
    Journal::WorkPackageJournal.column_names - ["id", "project_phase_definition_id"]
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

  # Detect changes in association journals by checking for additions and removals.
  def association_changes_condition_sql(table:, id_column:, value_columns:)
    "#{association_items_added_sql(table:, id_column:, value_columns:)} " \
      "UNION " \
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
