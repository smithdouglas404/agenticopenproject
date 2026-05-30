# frozen_string_literal: true

# -- copyright
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

# Builds the UNION ALL of journals and changesets for a work package's activity
# feed, normalised to `(id, kind, activity_at)` rows ordered newest-first.
#
# Hydration is intentionally left out: the paginator slices the page first, then
# loads Journal/Changeset records and applies the eager-loading wrapper. That
# keeps the wrapper running against the page slice instead of the full history.
#
# The carrier class is `Journal` for AR composition only — rows in this relation
# are never materialised as Journal records.
class WorkPackages::ActivitiesTab::Paginator::ActivitiesQuery
  KIND_JOURNAL = Journal.name
  KIND_CHANGESET = Changeset.name

  def initialize(work_package, filter:)
    @work_package = work_package
    @filter = filter
  end

  def call
    Journal
      .from(Arel.sql("(#{union_sql}) AS activities"))
      .select(Arel.sql("activities.id, activities.kind, activities.activity_at"))
      .order(Arel.sql("activities.activity_at DESC, activities.id DESC, activities.kind DESC"))
  end

  private

  attr_reader :work_package, :filter

  def union_sql
    parts = [journals_leg_sql]
    parts << changesets_leg_sql unless filter == :only_comments
    parts.join(" UNION ALL ")
  end

  def journals_leg_sql
    apply_filter(work_package.journals.internal_visible)
      .unscope(:order)
      .select("journals.id, #{quote(KIND_JOURNAL)} AS kind, journals.created_at AS activity_at")
      .to_sql
  end

  def apply_filter(scope)
    case filter
    when :only_comments
      scope.where.not(notes: [nil, ""])
    when :only_changes
      WorkPackages::ActivitiesTab::Paginator::JournalChangesFilter.apply(scope)
    else
      scope
    end
  end

  def changesets_leg_sql
    work_package
      .changesets
      .unscope(:order)
      .select("changesets.id, #{quote(KIND_CHANGESET)} AS kind, changesets.committed_on AS activity_at")
      .to_sql
  end

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
