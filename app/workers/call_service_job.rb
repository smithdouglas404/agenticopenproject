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

# Calls a service class in a background job.
#
# Designed for deferring service calls from migrations where the database
# schema may not yet be fully applied. The job checks for pending migrations
# before running and retries if any are found.
#
# Usage:
#   CallServiceJob.perform_later(
#     "Members::AddRoleService",
#     call_kwargs: { user_id: 42, role_id: 7, project_id: nil, send_notifications: false }
#   )
class CallServiceJob < ApplicationJob
  class ServiceCallFailed < StandardError; end

  # Transient errors (e.g. pending migrations) are retried with exponential backoff.
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  # Service result failures are permanent — fail the job immediately without retry.
  # Declared after retry_on StandardError so it takes precedence for ServiceCallFailed.
  retry_on ServiceCallFailed, attempts: 1

  queue_with_priority :low

  # @param service_class_name [String] Fully-qualified service class name
  # @param current_user_id [Integer, nil] Current user ID; nil uses the system user
  # @param call_kwargs [Hash] Keyword arguments forwarded to service.call(...)
  def perform(service_class_name, current_user_id: nil, call_kwargs: {})
    if ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool.migration_context.needs_migration?
      raise "#{self.class.name}: deferring #{service_class_name} — pending migrations detected"
    end

    current_user = current_user_id ? User.find(current_user_id) : User.system
    result = service_class_name.constantize
                               .new(current_user:)
                               .call(**call_kwargs.symbolize_keys)

    result.on_failure { |r| raise ServiceCallFailed, "#{service_class_name}#call failed: #{r.message}" }
  end
end
