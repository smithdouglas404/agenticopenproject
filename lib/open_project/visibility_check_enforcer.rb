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

# Runtime safeguard that ensures every SELECT touching a visibility-protected table
# either went through the table's `.visible(user)` scope (which annotates the SQL
# with `/* visibility_checked:<table> */`) or was explicitly bypassed with an
# annotated `.skip_visibility_check(reason:)` / `.skip_visibility_check_for(Model, reason:)`.
#
# Mirrors the pedagogy of `Concerns::Accounts::Authorization#authorization_check_required`:
# raise in development and test with a message that points the developer at the ways to
# satisfy the check, so the class of bug "I forgot `.visible(user)` and silently leaked
# records" cannot ship.
#
# Which tables are enforced is configured via `PROTECTED_TABLES` (populated from the
# `OP_VISIBILITY_ENFORCED_TABLES` env var). Tables not listed there are not checked,
# which lets us roll enforcement out one table at a time.
module OpenProject
  class VisibilityCheckMissing < StandardError; end

  module VisibilityCheckEnforcer
    CHECK_REGEX = %r{/\* visibility_checked:([^\s*]+) \*/}
    SKIP_REGEX  = %r{/\* skip_visibility_check:([^:]+):[^*]+\*/}

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

      # Run a block with the enforcer disabled for the current thread. Use from factories,
      # seeders, and other test/setup code that legitimately needs to load records without
      # running through a visible scope.
      def bypass
        prev = Thread.current[:visibility_check_bypass]
        Thread.current[:visibility_check_bypass] = true
        yield
      ensure
        Thread.current[:visibility_check_bypass] = prev
      end

      # Which tables the enforcer should verify. Defaults to empty, letting teams opt in
      # via the `OP_VISIBILITY_ENFORCED_TABLES` env var (comma-separated table names).
      def protected_tables
        @protected_tables ||= ENV.fetch("OP_VISIBILITY_ENFORCED_TABLES", "").split(",").map(&:strip).reject(&:empty?)
      end

      # Override for tests. Pass `nil` to reset to the env-var default.
      attr_writer :protected_tables

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
        sql.is_a?(String) && sql.match?(/\ASELECT\b/i) && protected_tables.any?
      end

      def missing_coverage(sql)
        referenced = protected_tables.select { |t| sql.match?(/\b(?:FROM|JOIN)\s+"?#{Regexp.escape(t)}"?\b/i) }
        return [] if referenced.empty?

        covered = sql.scan(CHECK_REGEX).flatten | sql.scan(SKIP_REGEX).flatten
        referenced - covered
      end

      def build_message(table, sql)
        klass_name = table.classify
        <<~MSG
          Visibility check missing for `#{table}` in the query below.

          The query references `#{table}` (a visibility-protected table) without
          a corresponding `.visible(user)` scope or explicit bypass.

          To fix, either:
            - Scope it:
                #{klass_name}.visible(current_user)...
            - If the protected table is joined or subqueried, merge its `visible` scope:
                .merge(#{klass_name}.visible(current_user))
            - Or bypass explicitly with a reason (requires justification):
                .skip_visibility_check(reason: "<why>")                    # for self
                .skip_visibility_check_for(#{klass_name}, reason: "<why>")  # for joined/subqueried

          SQL: #{sql}
        MSG
      end
    end
  end
end
