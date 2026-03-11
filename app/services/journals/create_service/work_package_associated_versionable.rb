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

class Journals::CreateService
  class WorkPackageAssociatedVersionable < Association
    def associated?
      journable.respond_to?(:work_package_associated_versions)
    end

    def cleanup_predecessor(predecessor, notes, cause)
      cleanup_predecessor_for(predecessor,
                              notes,
                              cause,
                              "work_package_associated_version_journals",
                              :journal_id,
                              :id)
    end

    def insert_sql
      sanitize(<<~SQL.squish, journable_id:)
        INSERT INTO
          work_package_associated_version_journals (
            journal_id,
            version_id,
            kind,
            name
          )
        SELECT
          #{id_from_inserted_journal_sql},
          v.id,
          a.kind,
          v.name
        FROM work_package_associated_versions a
        INNER JOIN versions v ON v.id = a.version_id
        WHERE
          #{only_if_created_sql}
          AND a.work_package_id = :journable_id
      SQL
    end

    def changes_sql
      sanitize(<<~SQL.squish, journable_id:)
        SELECT
          max_journals.journable_id
        FROM
          max_journals
        LEFT OUTER JOIN
          work_package_associated_version_journals
        ON
          work_package_associated_version_journals.journal_id = max_journals.id
        FULL JOIN
          (SELECT *
           FROM work_package_associated_versions
           WHERE work_package_associated_versions.work_package_id = :journable_id) current_assoc
        ON
          current_assoc.version_id = work_package_associated_version_journals.version_id
          AND current_assoc.kind    = work_package_associated_version_journals.kind
        WHERE
          (current_assoc.version_id IS NULL AND work_package_associated_version_journals.version_id IS NOT NULL)
          OR (work_package_associated_version_journals.version_id IS NULL AND current_assoc.version_id IS NOT NULL)
      SQL
    end
  end
end
