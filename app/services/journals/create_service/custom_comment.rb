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
  class CustomComment < Association
    def associated?
      journable.respond_to?(:custom_comments)
    end

    def cleanup_predecessor(predecessor)
      cleanup_predecessor_for(predecessor,
                              "custom_comment_journals",
                              :journal_id,
                              :id)
    end

    def insert_sql
      sanitize(<<~SQL.squish, journable_id:, journable_class_name:)
        INSERT INTO
          custom_comment_journals (
            journal_id,
            custom_field_id,
            text
          )
        SELECT
          #{id_from_inserted_journal_sql},
          custom_comments.custom_field_id,
          custom_comments.text
        FROM custom_comments
        INNER JOIN custom_fields
          ON custom_fields.id = custom_comments.custom_field_id
          AND custom_fields.has_comment = TRUE
        #{availability_join}
        WHERE
          #{only_if_created_sql}
          AND custom_comments.customized_id = :journable_id
          AND custom_comments.customized_type = :journable_class_name
          AND custom_comments.text != ''
      SQL
    end

    def changes_sql
      sanitize(<<~SQL.squish, journable_id:, customized_type: journable_class_name)
        SELECT
          max_journals.journable_id
        FROM
          max_journals
        LEFT OUTER JOIN
          custom_comment_journals
        ON
          custom_comment_journals.journal_id = max_journals.id
        FULL JOIN
          (SELECT custom_comments.*
           FROM custom_comments
           INNER JOIN custom_fields
             ON custom_fields.id = custom_comments.custom_field_id
             AND custom_fields.has_comment = TRUE
           #{availability_join}
           WHERE custom_comments.customized_id = :journable_id
             AND custom_comments.customized_type = :customized_type) custom_comments
        ON
          custom_comments.custom_field_id = custom_comment_journals.custom_field_id
        WHERE
          COALESCE(custom_comments.text, '') != COALESCE(custom_comment_journals.text, '')
      SQL
    end

    private

    def availability_join
      return "" unless journable.is_a?(Project)

      <<~SQL # rubocop:disable Rails/SquishedSQLHeredocs
        INNER JOIN project_custom_field_project_mappings
          ON project_custom_field_project_mappings.custom_field_id = custom_fields.id
          AND project_custom_field_project_mappings.project_id = :journable_id
      SQL
    end
  end
end
