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

module OpenProject
  class ActionAuthorizer
    module Registrable
      extend ActiveSupport::Concern

      class_methods do
        def register_action_authorization(action, method:)
          on = module_parent.name.singularize.to_sym

          OpenProject::ActionAuthorizer.register(action, on:, contract: self, method:)
        end
      end
    end

    class << self
      def register(action, on:, contract:, method:)
        registry[on.to_s.to_sym][action] = [contract, method]
      end

      # TODO: check if on is really optional.
      def allowed?(action, user:, on: nil, scope: nil)
        on = determine_on(on, scope)
        raise ArgumentError, "Either on or scope needs to be provided." unless on

        entry = find_check(action, on)

        # TODO: Check for whether eager loading is active
        if entry.nil? && Rails.env.local?
          eager_load_contracts_for(on)
          entry = find_check(action, on)
        end

        raise ArgumentError, "No authorization check registered for ':#{action}' on the model #{on}." unless entry

        contract, method = entry
        contract.to_s.constantize.public_send(method, user:, scope:)
      end

      def reset!
        @registry = {}
        @loaded_namespaces = Set.new
      end

      private

      def registry
        @registry ||= Hash.new { |h, k| h[k] = {} }
      end

      def loaded_namespaces
        @loaded_namespaces ||= Set.new
      end

      def determine_on(on, scope)
        if on.is_a?(Class)
          on.to_s.to_sym
        elsif scope.is_a?(ActiveRecord::Base)
          scope.class.to_s.to_sym
        end
      end

      def find_check(action, on)
        registry[on][action]
      end

      def eager_load_contracts_for(on)
        namespace = on.to_s.pluralize.safe_constantize

        return if namespace.nil? || loaded_namespaces.include?(namespace)

        loaded_namespaces << namespace
        # TODO: check if contracts can be identified so that only those are loaded and not all of e.g Meetings
        Rails.autoloaders.each { |loader| loader.eager_load_namespace(namespace) }
      end
    end
  end
end
