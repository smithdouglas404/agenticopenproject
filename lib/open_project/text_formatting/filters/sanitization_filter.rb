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

module OpenProject::TextFormatting
  module Filters
    module SanitizationFilter
      # Prefix for all id and name attributes so they cannot clobber document/window
      # (e.g. id="constructor" becomes id="op-frag-constructor"). Anchors still work
      # because we rewrite fragment links to use the same prefix. Used by
      # TableOfContentsFilter when it assigns heading ids.
      FRAGMENT_ID_PREFIX = "op-frag-"

      # Macro-specific data attributes that must survive sanitization.
      # Selma does not support wildcard data-* matching, so we enumerate known attribute names.
      MACRO_DATA_ATTRIBUTES = %w[
        data-type data-classes data-page data-include-parent data-url data-name
        data-id data-detailed data-macro-name data-project data-wiki-page data-filter
      ].freeze

      # Build a Selma sanitization config for use as HTMLPipeline's sanitization_config.
      # Must be a method (not a constant) because allowed protocols are read from the DB.
      def self.config
        base_elements = HTMLPipeline::SanitizationFilter::DEFAULT_CONFIG[:elements]
        base_attrs    = HTMLPipeline::SanitizationFilter::DEFAULT_CONFIG[:attributes]
        base_protocols = HTMLPipeline::SanitizationFilter::DEFAULT_CONFIG[:protocols]

        Selma::Sanitizer::Config.freeze_config({
          elements: base_elements + %w[macro mention],

          attributes: base_attrs.merge(
            all: base_attrs[:all] + %w[class style],
            "macro"   => ["class"] + MACRO_DATA_ATTRIBUTES,
            "mention" => %w[class data-type data-text data-id],
            "figure"  => %w[class style],
            "img"     => (base_attrs["img"] || []) + %w[style],
            "table"   => (base_attrs["table"] || []) + %w[style],
            "th"      => (base_attrs["th"]    || []) + %w[style],
            "tr"      => (base_attrs["tr"]    || []) + %w[style],
            "td"      => (base_attrs["td"]    || []) + %w[style],
          ),

          protocols: base_protocols.merge(
            "a" => { "href" => Setting::AllowedLinkProtocols.all + [:relative] }
          ),

          allow_comments: false,
          allow_doctype:  false,
        })
      end

      # NodeFilter that prefixes all id/name attributes with FRAGMENT_ID_PREFIX so
      # they cannot clobber document/window properties (e.g. id="constructor").
      # Also rewrites same-document fragment links so they match the prefixed ids.
      class FragmentIdPrefixFilter < HTMLPipeline::NodeFilter
        SELECTOR = Selma::Selector.new(match_element: "*")

        def selector
          SELECTOR
        end

        def handle_element(element)
          prefix = SanitizationFilter::FRAGMENT_ID_PREFIX

          # Prefix id and name attributes
          %w[id name].each do |attr|
            val = element[attr]
            next if val.blank?
            next if val.start_with?(prefix)

            element[attr] = "#{prefix}#{val}"
          end

          # Rewrite fragment-only href values on <a> tags
          return unless element.tag_name == "a"

          href = element["href"]
          return if href.blank?
          return unless href.start_with?("#") && href.length > 1

          fragment = href.slice(1..)
          return if fragment.empty? || fragment.start_with?(prefix)

          element["href"] = "##{prefix}#{fragment}"
        end
      end
    end
  end
end
