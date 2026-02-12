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
    class << self
      def register(name, scope:, contract:, method:)
        registry[scope.to_s.to_sym][name] = [contract, method]
      end

      def allowed?(name, user:, scope: nil)
        entry = find_check(name, scope.class) || find_check(name, nil)

        unless entry
          scope_desc = scope.nil? ? "nil" : scope.class.name
          raise ArgumentError, "No authorization check registered for '#{name}' with scope #{scope_desc}"
        end

        contract, method = entry
        contract.to_s.constantize.public_send(method, user:, scope:)
      end

      def reset!
        @registry = {}
      end

      private

      def registry
        @registry ||= Hash.new { |h, k| h[k] = {} }
      end

      def find_check(name, scope)
        return registry[:''][name] if scope.nil?

        check = registry[scope.to_s.to_sym][name]

        check || find_check(name, scope.superclass)
      end
    end
  end
end
