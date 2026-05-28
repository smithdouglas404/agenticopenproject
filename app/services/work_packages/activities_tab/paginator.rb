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

# Paginates work package activities (journals and changesets) with support for
# filtering and anchor navigation.
#
# Filter modes:
# - :all - Shows all activities (default)
# - :only_comments - Shows only journals with notes
# - :only_changes - Shows only journals with detected changes using SQL heuristics
#
# Anchor format:
# - "comment-{journal_id}" - Navigate to specific journal by ID
# - "activity-{sequence_version}" - Navigate to journal by sequence version
#
# Anchored navigation bypasses the active filter so a deep link to a record
# that wouldn't match the filter still resolves.
#
# Internally, the activities feed is materialised as a single UNION ALL
# relation of journals and changesets (see {ActivitiesQuery}) and paginated
# by pagy at the database level. Only the page slice is hydrated and wrapped
# for eager-loading, keeping per-request cost independent of total history size.
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
  include Pagy::Method
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
    anchor_type, target_record_id = parse_anchor

    pagy_obj, page_relation =
      if anchor_type && target_record_id
        pagy_at_anchor(anchor_type, target_record_id)
      else
        pagy(:offset, activities_scope, **pagy_options)
      end

    activities = load_activities(page_relation)
    activities = activities.reverse if journal_sorting.asc?

    [pagy_obj, activities]
  end

  private

  # Activities relation (UNION of journals and changesets). Anchored
  # navigation passes `filter: :all` so a deep link to a record that
  # wouldn't match the active filter still resolves.
  def activities_scope(filter: self.filter)
    ActivitiesQuery.new(work_package, filter:).call
  end

  def visible_journals
    work_package.journals.internal_visible
  end

  def limit
    params[:limit] || Pagy::DEFAULT[:limit]
  end

  def pagy_options
    {
      page: params[:page] || 1,
      limit:,
      request: { params: }
    }.compact
  end

  def parse_anchor
    anchor = params[:anchor] # e.g., "comment-78758" (without #)
    return unless anchor

    match = anchor.match(/^(comment|activity)-(\d+)$/)
    return unless match

    [match[1].inquiry, match[2].to_i]
  end

  # An unresolvable anchor (deleted, never existed, not visible to the user)
  # opens the tab at the newest page, the same as opening it without an
  # anchor. Any `params[:page]` sent alongside is intentionally ignored: the
  # anchor was the explicit navigation intent.
  def pagy_at_anchor(anchor_type, target_record_id)
    scope = activities_scope(filter: :all)
    page = page_for_anchor(scope, anchor_type, target_record_id) || 1
    pagy(:offset, scope, **pagy_options, page:)
  end

  # Resolves an anchor to its target page by counting records ahead of it.
  # Returns nil when the anchor is unresolvable so the caller falls back.
  def page_for_anchor(scope, anchor_type, target_record_id)
    activity_at, anchor_id = locate_anchor(anchor_type, target_record_id)
    return nil unless activity_at && anchor_id

    rows_ahead = scope
      .where("(activities.activity_at, activities.id) > (?, ?)", activity_at, anchor_id)
      .count(:all)

    (rows_ahead / limit) + 1
  end

  # Anchors must observe the same visibility rules as the activities feed.
  # Otherwise the count-ahead would route an unviewable journal to a page
  # number and leak the existence of internal journals through the URL.
  def locate_anchor(anchor_type, target_record_id)
    if anchor_type.comment?
      visible_journals.where(id: target_record_id).pick(:created_at, :id)
    elsif anchor_type.activity?
      locate_anchor_by_sequence_version(target_record_id)
    end
  end

  def locate_anchor_by_sequence_version(sequence_version)
    visible_journals
      .with_sequence_version
      .where(ranked: { sequence_version: sequence_version })
      .pick(:created_at, :id)
  end

  def load_activities(page_relation)
    activity_refs = page_relation.pluck(Arel.sql("activities.kind"), Arel.sql("activities.id"))
    activities_by_kind = load_page_activities_by_kind(activity_refs)

    ordered_activities = activity_refs.filter_map { |kind, id| activities_by_kind[kind][id] }
    eager_load_journals(ordered_activities)
  end

  def load_page_activities_by_kind(activity_refs)
    ids_by_kind = activity_refs.group_by(&:first).transform_values { it.map(&:last) }
    {
      ActivitiesQuery::KIND_JOURNAL => load_page_journals(ids_by_kind[ActivitiesQuery::KIND_JOURNAL] || []),
      ActivitiesQuery::KIND_CHANGESET => load_page_changesets(ids_by_kind[ActivitiesQuery::KIND_CHANGESET] || [])
    }
  end

  def load_page_journals(ids)
    return {} if ids.empty?

    Journal
      .where(id: ids)
      .with_sequence_version
      .includes(:user, :customizable_journals, :attachable_journals, :storable_journals, :notifications)
      .index_by(&:id)
  end

  def load_page_changesets(ids)
    return {} if ids.empty?

    Changeset
      .where(id: ids)
      .includes(:user, :repository)
      .index_by(&:id)
  end

  # Substitutes journals with their eager-loading wrappers so the wrapper's
  # batch queries (journable, predecessor, data, notifications) run against
  # the page slice only. Order from the input is preserved.
  def eager_load_journals(activities)
    journals = activities.grep(Journal)
    wrapped_by_id = API::V3::Activities::ActivityEagerLoadingWrapper.wrap(journals).index_by(&:id)

    activities.map { it.is_a?(Journal) ? wrapped_by_id[it.id] : it }
  end
end
