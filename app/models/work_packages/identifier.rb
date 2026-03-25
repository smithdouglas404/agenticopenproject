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

module WorkPackages::Identifier
  extend ActiveSupport::Concern

  included do
    extend FriendlyId

    # Configures FriendlyId with slug history and a custom ghost finder.
    # The GhostFinder extends the standard lookup chain so that identifiers
    # using old project prefixes still resolve — e.g. "PROJ-11" finds the
    # right WP even after the project was renamed to "BETTER".
    friendly_id :identifier, slug_column: :identifier do |config|
      config.use %i[finders history]
      config.finder_methods = WorkPackages::Identifier::GhostFinder
      FriendlyId::Finders.setup(WorkPackage)
    end

    after_create :allocate_identifier!, if: -> { Setting::WorkPackageIdentifier.alphanumeric? && identifier.blank? }

    # FriendlyId::Slugged adds after_validation :unset_slug_if_invalid, which reverts the
    # slug column when validation fails. Since the identifier is managed by the service layer
    # (not FriendlyId's slug generator), we disable this behaviour entirely.
    def unset_slug_if_invalid; end
  end

  private

  # Allocates a project-scoped sequence number and composes the semantic identifier.
  # Uses an advisory lock to serialize concurrent allocations on the same project.
  def allocate_identifier!
    OpenProject::Mutex.with_advisory_lock_transaction(project, "wp_sequence") do
      next_seq = project.increment_wp_sequence!

      update_columns(sequence_number: next_seq,
                     identifier: "#{project.identifier}-#{next_seq}")
    end
  end
end
