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

# In the context of the baseline-comparison feature, this class represents an active-record relation
# that queries historic data, i.e. performs its query e.g. on the `work_package_journals` table
# rather than the `work_packages` table.
#
# Usage:
#
#     timestamp = 1.year.ago
#     active_record_relation = WorkPackage.where(subject: "Foo")
#     historic_relation = Journable::HistoricActiveRecordRelation.new(active_record_relation, timestamp:)
#
# See also:
#
# - https://github.com/opf/openproject/pull/11243
# - https://community.openproject.org/projects/openproject/work_packages/26448
#
class Journable::HistoricActiveRecordRelation < ActiveRecord::Relation
  attr_accessor :timestamp

  include ActiveRecord::Delegation::ClassSpecificRelation

  def initialize(relation, timestamp:)
    raise ArgumentError, "Expected ActiveRecord::Relation" unless relation.is_a? ActiveRecord::Relation

    super(relation.klass)
    relation.instance_variables.each do |key|
      instance_variable_set key, relation.instance_variable_get(key)
    end

    self.timestamp = Array(timestamp)
    readonly!
  end

  def add_wp_cte(arel)
    # TODO: turn wp agnostic
    # Add interval check into here
    # Remove

    relation = Journal
                 .joins(<<-SQL.squish)
                   INNER JOIN #{model.journal_class.table_name}
                   ON "journals"."data_type" = '#{model.journal_class.name}'
                   AND "journals"."data_id" = "#{model.journal_class.table_name}"."id"
                 SQL
                 .joins(<<-SQL.squish)
                   INNER JOIN #{model.table_name}
                   ON #{model.table_name}.id = "#{Journal.table_name}"."journable_id"
                 SQL
                  .select(
                    "journals.journable_id AS id",
                    "journals.id AS journal_id",
                    "#{model.table_name}.created_at",
                    "journals.updated_at",
                    "CASE #{timestamp_case_when_statements} END as timestamp",
                    *model.journal_class.column_names
                          .reject { it == "id" }
                          .map { |c| "#{model.journal_class.table_name}.#{c}" },
                    *model.column_names_missing_in_journal.map do |missing_column_name|
                      "null as #{missing_column_name}"
                    end
                  )

    relation = add_timestamp_condition(relation)

    work_packages_cte = Arel::Table.new(model.table_name)
    work_packages_cte = Arel::Nodes::As.new(work_packages_cte, relation.arel)

    if arel.ast.with
      arel.ast.with.expr.unshift(work_packages_cte)
    else
      arel.ast.with = Arel::Nodes::With.new([work_packages_cte])
    end

    arel
  end

  # Patch the `pluck` method of an active-record relation
  # so that columns callers might expect but that do not exist on the journals table are ignored.
  def pluck(*column_names)
    column_names.map! do |column_name|
      if model.column_names_missing_in_journal.include?(column_name.to_s)
        Rails.logger.warn "Cannot pluck column `#{column_name}` because this attribute is not journalized," \
                          "i.e. it is missing in the #{journal_class.table_name} table."
        "null as #{column_name}"
      else
        column_name
      end
    end

    super
  end

  alias_method :original_build_arel, :build_arel

  # Patch the arel object, which is used to construct the sql query, in order
  # to modify the query to search for historic data.
  #
  def build_arel(connection, aliases = nil)
    relation = self

    relation = substitute_join_tables_in_where_clause(relation)

    # Based on the previous modifications, build the algebra object.
    arel = relation.call_original_build_arel(connection, aliases)

    add_wp_cte(arel)
  end

  def call_original_build_arel(connection, aliases = nil)
    original_build_arel(connection, aliases)
  end

  private

  # Additional table joins can appear in the where clause, such as the custom_values table join.
  # We need to substitute the table name ("custom_values") with the journalized table name
  # ("customized_journals") in order to retrieve historic data from the journalized table.

  def substitute_join_tables_in_where_clause(relation)
    relation.where_clause.instance_variable_get(:@predicates).each do |predicate|
      substitute_custom_values_join_in_predicate(predicate)
    end
    relation
  end

  # For simplicity's sake we replace the "custom_values" join only when the predicate is a String.
  # This is the way we are receiving the predicate from the `Queries::WorkPackages::Filter::CustomFieldFilter`
  # The joins are defined in the `Queries::WorkPackages::Filter::CustomFieldContext#where_subselect_joins`
  # method. If we ever change that method to use Arel, we will need to implement the substitution
  # for Arel objects as well.
  def substitute_custom_values_join_in_predicate(predicate)
    if predicate.is_a? String
      predicate.gsub! /JOIN (?<!_)#{CustomValue.table_name}/, "JOIN #{Journal::CustomizableJournal.table_name}"
      predicate.gsub! "JOIN \"#{CustomValue.table_name}\"", "JOIN \"#{Journal::CustomizableJournal.table_name}\""

      customized_type = /custom_values.customized_type = '#{model.name}'/
      customized_id   = /custom_values.customized_id = #{model.table_name}.id/

      # The customizable_journals table has no direct relation to the work_packages table,
      # but it has to the journals table. We join it to the journals table instead.
      journal_id = "customizable_journals.journal_id = #{model.table_name}.journal_id"

      predicate.gsub! /#{customized_type}\s*AND #{customized_id}/m, journal_id

      predicate.gsub! "AND custom_values.custom_field_id =", "AND customizable_journals.custom_field_id ="
      predicate.gsub! "WHERE custom_values.value", "WHERE customizable_journals.value"
    end
  end

  # Add a timestamp condition: Select the work package journals that are the
  # current ones at the given timestamp.
  #
  def add_timestamp_condition(relation)
    timestamp_condition = timestamp.map do |t|
      Journal.where(journable_type: model.name).at_timestamp(t)
    end.reduce(&:or)

    relation.merge(timestamp_condition)
  end

  def timestamp_case_when_statements
    timestamp
      .map do |timestamp|
      comparison_time = case timestamp
                        when Timestamp
                          timestamp.to_time
                        when DateTime
                          timestamp.in_time_zone
                        else
                          raise NoMethodError, "Unknown timestamp type: #{timestamp.class}"
                        end

      "WHEN \"journals\".\"validity_period\" @> timestamp with time zone '#{comparison_time}' THEN '#{timestamp}'"
    end
      .join(" ")
  end
end
