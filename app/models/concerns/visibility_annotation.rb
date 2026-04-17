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

# Adds SQL-comment annotations to ActiveRecord relations so `OpenProject::VisibilityCheckEnforcer`
# can verify that every query touching a visibility-protected table went through a known-safe
# path (either its `visible(user)` scope, or an explicit, reasoned bypass).
#
# Attached to both the class (via `ApplicationRecord.extend`) and to every `ActiveRecord::Relation`
# (via initializer). Use from a scope definition:
#
#   scope :visible, ->(user = User.current) {
#     allowed_to(user, :view_work_packages).visibility_checked
#   }
#
# Or, for the narrow cases where a bypass is intentional (admin-only actions, system-run jobs):
#
#   Model.skip_visibility_check(reason: "admin-only action, archived records required")
#   relation.skip_visibility_check_for(JoinedModel, reason: "parent scope already enforces visibility")
module VisibilityAnnotation
  # Mark this relation as visibility-checked for its own table. Used inside `.visible` scopes.
  def visibility_checked
    annotate("visibility_checked:#{_visibility_annotation_table_name}")
  end

  # Explicit bypass for the receiver's own table. Requires a non-empty reason so the intent is
  # visible in code review and grep-able in audits.
  def skip_visibility_check(reason:)
    raise ArgumentError, "skip_visibility_check requires a non-empty `reason:`" if reason.to_s.strip.empty?

    annotate("skip_visibility_check:#{_visibility_annotation_table_name}:#{reason}")
  end

  # Explicit bypass for another model's table — used when that table appears in a JOIN or
  # subquery of the current relation.
  def skip_visibility_check_for(model, reason:)
    raise ArgumentError, "skip_visibility_check_for requires a non-empty `reason:`" if reason.to_s.strip.empty?

    annotate("skip_visibility_check:#{model.table_name}:#{reason}")
  end

  private

  def _visibility_annotation_table_name
    is_a?(Class) ? table_name : klass.table_name
  end
end
