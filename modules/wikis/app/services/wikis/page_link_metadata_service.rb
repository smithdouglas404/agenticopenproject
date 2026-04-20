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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Wikis
  class PageLinkMetadataService
    def initialize(page_links)
      @page_links = page_links
      @result = ServiceResult.success(errors: ActiveModel::Errors.new(self))
    end

    def call
      metadata = @page_links.group_by(&:provider).filter_map do |provider, pages|
        result = provider.resolve("queries.pages").call(provider:, page_identifiers: pages.map(&:identifiers))
        result.value_or { add_wiki_error(it) and next }
      end

      @result.result = enrich_models(@page_links, metadata.flatten)
      @result
    end

    private

    def add_wiki_error(error)
      @result.add_error(:base, error.message)
    end

    def enrich_models(page_links, metadata)
      # Expectation is that the result from the PagesQuery is an array of "Result::Pages"
      identifier_title_map = metadata.sort_by(&:identifier).to_h { [it.identifier, it.title] }
      variable_placeholders = build_placeholders(identifier_title_map.size)

      result_scope(page_links.pluck(:id), metadata_join_sql(variable_placeholders, identifier_title_map))
    end

    def result_scope(ids, join_expression)
      PageLink.where(id: ids).order(:id).joins(join_expression).select("page_links.*, metadata.tile as title")
    end

    def metadata_join_sql(variable_placeholders, identifier_title_map)
      ActiveRecord::Base.sanitize_sql_array([variable_placeholders, *identifier_title_map.flatten])
    end

    def build_placeholders(amount)
      variable_placeholders = Array.new(amount, "(?,?)").join(",")
      <<~SQL.squish
        LEFT JOIN (VALUES #{variable_placeholders}) AS metadata (identifier, title)
          ON metadata.tile = page_links.identifier
      SQL
    end
  end
end
