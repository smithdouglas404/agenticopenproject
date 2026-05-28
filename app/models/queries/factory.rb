# frozen_string_literal: true

# -- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2010-2024 the OpenProject GmbH
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
# ++

class Queries::Factory
  class << self
    def find(id, query_class:, params:, user:, duplicate: false)
      find_static_query_and_set_attributes(id, query_class, params, user, duplicate:) ||
      find_persisted_query_and_set_attributes(id, query_class, params, user, duplicate:)
    end

    private

    def find_static_query_and_set_attributes(id, query_class, params, user, duplicate:)
      query = query_namespace(query_class)::Static.query(id)

      return unless query

      static_filters = query.filters.dup

      query = duplicate_query(query) if duplicate || params.any?

      if params.any?
        set_query_attributes(query, query_class, with_preserved_static_filters(static_filters, params), user)
      else
        query
      end
    end

    # When user-provided params include a filters list, preserve any static query
    # filters (e.g. active=false for the archived query) that aren't explicitly
    # overridden by the user params.  This prevents the search box from wiping
    # the archived/active constraint that defines the static query.
    def with_preserved_static_filters(static_filters, params)
      return params unless params[:filters]

      user_filter_attributes = params[:filters].map { |f| f[:attribute].to_s }

      filters_to_preserve = static_filters
        .reject { |f| user_filter_attributes.include?(f.name.to_s) }
        .map { |f| { attribute: f.name.to_s, operator: f.operator, values: f.values } }

      return params if filters_to_preserve.empty?

      params.merge(filters: filters_to_preserve + params[:filters])
    end

    def find_persisted_query_and_set_attributes(id, query_class, params, user, duplicate:)
      query = query_class.visible(user).find_by(id:)

      return unless query

      query.valid_subset!
      query.clear_changes_information

      query = duplicate_query(query) if duplicate

      if params.any?
        set_query_attributes(query, query_class, params, user)
      else
        query
      end
    end

    def duplicate_query(query)
      query.class.new(query.attributes.slice("filters", "orders", "selects"))
    end

    def set_query_attributes(query, query_class, params, user)
      query_namespace(query_class)::SetAttributesService
        .new(user:,
             model: query,
             contract_class: Queries::LoadingContract)
        .call(params)
        .result
    end

    def query_namespace(query_class)
      query_class.name.pluralize.constantize
    end
  end
end
