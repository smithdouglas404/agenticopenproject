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

# Runtime safeguard that ensures every SELECT touching a visibility-relevant
# table either went through the table's `.visible(user)` scope (which annotates
# the SQL with `/* visibility_checked:<table> */`) or was explicitly bypassed
# with an annotated `.skip_visibility_check(reason:)` /
# `.skip_visibility_check_for(Model, reason:)`.
#
# Mirrors the pedagogy of `Concerns::Accounts::Authorization#authorization_check_required`:
# raise in development and test with a message that points at the ways to
# satisfy the check, so "I forgot `.visible(user)` and silently leaked records"
# cannot ship.
#
# Enforcement applies to every DB table *except* those listed in
# `EXCLUDED_TABLES` (framework internals, background-job state, global
# configuration, etc.). CTE aliases and subquery names are ignored because the
# enforcer only considers names that match real tables in the connection.
module OpenProject
  class VisibilityCheckMissing < StandardError; end

  module VisibilityCheckEnforcer
    CHECK_REGEX = %r{/\* visibility_checked:([^\s*]+) \*/}
    SKIP_REGEX  = %r{/\* skip_visibility_check:([^:]+):[^*]+\*/}
    TABLE_REF_REGEX = /\b(?:FROM|JOIN)\s+"?([A-Za-z_][A-Za-z0-9_]*)"?/i

    # Tables that do not carry per-user visibility semantics and are excluded
    # from enforcement. Keep this list conservative — only add tables whose
    # contents are purely infrastructure (not user-owned data) or whose access
    # is already gated by a different mechanism.
    EXCLUDED_TABLES = %w[
      ar_internal_metadata
      schema_migrations

      good_jobs
      good_job_batches
      good_job_executions
      good_job_processes
      good_job_settings

      sessions
      settings
      enabled_modules

      paper_trail_audits
    ].freeze

    class << self
      # Install the sql.active_record subscriber. Idempotent.
      def install!
        return if @installed

        @subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
          enforce!(ActiveSupport::Notifications::Event.new(*args).payload)
        end
        @installed = true
      end

      # Remove the subscriber. Primarily for tests.
      def uninstall!
        return unless @installed

        ActiveSupport::Notifications.unsubscribe(@subscriber)
        @subscriber = nil
        @installed = false
      end

      # Run a block with the enforcer disabled for the current thread. Use from
      # factories, seeders, and other test/setup code that legitimately needs
      # to load records without running through a visible scope.
      def bypass
        prev = Thread.current[:visibility_check_bypass]
        Thread.current[:visibility_check_bypass] = true
        yield
      ensure
        Thread.current[:visibility_check_bypass] = prev
      end

      # The set of real DB tables the enforcer will check. Computed lazily as
      # `connection.tables - EXCLUDED_TABLES`. Assign `nil` to reset the cache
      # (primarily from tests after overriding).
      def enforced_tables
        @enforced_tables ||= (ActiveRecord::Base.connection.tables - EXCLUDED_TABLES).freeze
      end

      attr_writer :enforced_tables

      def enforce!(payload)
        return if skip_payload?(payload)

        sql = payload[:sql]
        missing = missing_coverage(sql)
        return if missing.empty?

        raise VisibilityCheckMissing, build_message(missing.first, sql)
      end

      private

      def skip_payload?(payload)
        Thread.current[:visibility_check_bypass] ||
          payload[:cached] ||
          payload[:name] == "SCHEMA" ||
          !enforceable_sql?(payload[:sql])
      end

      def enforceable_sql?(sql)
        sql.is_a?(String) && sql.match?(/\ASELECT\b/i)
      end

      def missing_coverage(sql)
        referenced = sql.scan(TABLE_REF_REGEX).flatten.map(&:downcase).uniq & enforced_tables
        return [] if referenced.empty?

        covered = sql.scan(CHECK_REGEX).flatten | sql.scan(SKIP_REGEX).flatten
        referenced - covered
      end

      def build_message(table, sql)
        klass_name = table.classify
        <<~MSG
          Visibility check missing for `#{table}` in the query below.

          The query references `#{table}` without a corresponding `.visible(user)`
          scope or explicit bypass. To fix, either:

            - Scope it:
                #{klass_name}.visible(current_user)...
            - If the table is joined or subqueried, merge its `visible` scope:
                .merge(#{klass_name}.visible(current_user))
            - Or bypass explicitly with a reason (requires justification):
                .skip_visibility_check(reason: "<why>")                     # for self
                .skip_visibility_check_for(#{klass_name}, reason: "<why>")  # for joined/subqueried

          If the table is purely infrastructure and should never require this
          check, add it to OpenProject::VisibilityCheckEnforcer::EXCLUDED_TABLES.

          SQL: #{sql}
        MSG
      end
    end
  end
end
