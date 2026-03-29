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

module WorkPackages
  module SemanticIds
    # Idempotent backfill: assigns sequence numbers to existing WPs and populates
    # the semantic_ids registry for all projects.
    #
    # Safe to re-run — skips WPs that already have sequence_number set and
    # uses find_or_create_by! to avoid duplicate registry rows.
    class BackfillService
      def self.run
        new.run
      end

      def run
        Project.find_each do |project|
          backfill_project(project)
        end
      end

      private

      def backfill_project(project)
        # 1. Assign sequence numbers to WPs that don't have one yet (ordered by id
        #    to keep numbers chronological).
        current_max = WorkPackage.where(project:).maximum(:sequence_number).to_i

        WorkPackage.where(project:, sequence_number: nil).order(:id).find_each do |wp|
          current_max += 1
          wp.update_columns(sequence_number: current_max)
        end

        project.update_columns(wp_sequence_counter: current_max)

        # 2. Populate registry and semantic_id for every WP in the project.
        WorkPackage.where(project:).find_each do |wp|
          sid = "#{project.identifier}-#{wp.sequence_number}"
          WorkPackageSemanticId.find_or_create_by!(identifier: sid, work_package_id: wp.id)
          wp.update_columns(semantic_id: sid) if wp.semantic_id != sid
        end
      end
    end
  end
end
