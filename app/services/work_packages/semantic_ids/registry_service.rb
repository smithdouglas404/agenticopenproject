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
    # Manages the work_package_semantic_ids registry: allocating sequence numbers,
    # writing registry entries on creation/move, and updating them on project rename.
    class RegistryService
      # Called after a new WP is saved. Allocates a sequence number, sets it on
      # the WP, and writes the initial registry entry.
      def self.register_new(work_package)
        new(work_package).register_new
      end

      # Called after a WP move (project changed). Retires the current registry
      # entry and inserts a new one in the target project's namespace.
      def self.register_move(work_package)
        new(work_package).register_move
      end

      # Called after a project identifier rename. Bulk-inserts new current
      # entries for every WP that ever lived in this project.
      def self.register_project_rename(project, old_identifier)
        new_instance = allocate
        new_instance.register_project_rename(project, old_identifier)
      end

      def initialize(work_package)
        @work_package = work_package
      end

      def register_new
        project = @work_package.project
        seq = allocate_sequence!(project)
        @work_package.update_columns(sequence_number: seq)
        WorkPackageSemanticId.create!(
          identifier: "#{project.identifier}-#{seq}",
          work_package_id: @work_package.id,
          current: true
        )
      end

      def register_move
        project = @work_package.project
        seq = allocate_sequence!(project)
        @work_package.update_columns(sequence_number: seq)

        WorkPackageSemanticId.transaction do
          WorkPackageSemanticId
            .where(work_package_id: @work_package.id, current: true)
            .update_all(current: false)

          WorkPackageSemanticId.create!(
            identifier: "#{project.identifier}-#{seq}",
            work_package_id: @work_package.id,
            current: true
          )
        end
      end

      def register_project_rename(project, old_identifier)
        new_prefix = project.identifier

        WorkPackageSemanticId.transaction do
          # Retire all current entries that carry the old prefix
          WorkPackageSemanticId
            .where(current: true)
            .where("identifier LIKE ?", "#{sanitize_like(old_identifier)}-%")
            .update_all(current: false)

          # Bulk-insert new current entries for every WP ever associated with the old prefix.
          # The NOT EXISTS guard makes this idempotent and safe under concurrent WP creation.
          WorkPackageSemanticId.connection.execute(<<~SQL.squish)
            INSERT INTO work_package_semantic_ids (identifier, work_package_id, current)
            SELECT '#{sanitize_sql(new_prefix)}-' || w.sequence_number,
                   s.work_package_id,
                   true
            FROM work_package_semantic_ids s
            JOIN work_packages w ON w.id = s.work_package_id
            WHERE s.identifier LIKE '#{sanitize_sql(old_identifier)}-%'
            AND NOT EXISTS (
              SELECT 1 FROM work_package_semantic_ids x
              WHERE x.identifier = '#{sanitize_sql(new_prefix)}-' || w.sequence_number
            )
          SQL
        end
      end

      private

      # Atomically increments the project counter and returns the new value.
      def allocate_sequence!(project)
        project.with_lock do
          project.increment!(:wp_sequence_counter)
          project.wp_sequence_counter
        end
      end

      def sanitize_like(str)
        str.gsub(/[%_\\]/) { |c| "\\#{c}" }
      end

      def sanitize_sql(str)
        WorkPackageSemanticId.connection.quote_string(str)
      end
    end
  end
end
