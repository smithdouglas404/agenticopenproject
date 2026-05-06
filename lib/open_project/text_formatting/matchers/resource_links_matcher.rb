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
  module Matchers
    # OpenProject links matching
    #
    # Examples:
    #   Issues:
    #     #52 -> Link to issue #52
    #   Changesets:
    #     r52 -> Link to revision 52
    #     commit:a85130f -> Link to scmid starting with a85130f
    #   Documents:
    #     document#17 -> Link to document with id 17
    #     document:Greetings -> Link to the document with title "Greetings"
    #     document:"Some document" -> Link to the document with title "Some document"
    #   Versions:
    #     version#3 -> Link to version with id 3
    #     version:1.0.0 -> Link to version named "1.0.0"
    #     version:"1.0 beta 2" -> Link to version named "1.0 beta 2"
    #   Attachments:
    #     attachment:file.zip -> Link to the attachment of the current object named file.zip
    #   Source files:
    #     source:"some/file" -> Link to the file located at /some/file in the project's repository
    #     source:"some/file@52" -> Link to the file's revision 52
    #     source:"some/file#L120" -> Link to line 120 of the file
    #     source:"some/file@52#L120" -> Link to line 120 of the file's revision 52
    #     export:"some/file" -> Force the download of the file
    #   Forum messages:
    #     message#1218 -> Link to message with id 1218
    #
    #   Links can refer other objects from other projects, using project identifier:
    #     identifier:r52
    #     identifier:document:"Some document"
    #     identifier:version:1.0.0
    #     identifier:source:some/file
    class ResourceLinksMatcher < RegexMatcher
      # Per-render cache of WorkPackage records referenced by `#N` plain links.
      # Stored on `RequestStore.store` (matching the `Cache`, `Setting`,
      # `CustomStyle`, and `WorkPackage#available_custom_field_key` patterns
      # already in this codebase) and managed via `with_preloaded_resources`,
      # which save/restores around its block to keep nested `format_text`
      # calls correct.
      WORK_PACKAGES_LOOKUP_KEY = :text_formatting_work_packages_lookup
      private_constant :WORK_PACKAGES_LOOKUP_KEY

      include ::OpenProject::TextFormatting::Truncation
      # used for the work package quick links
      include WorkPackagesHelper
      # Used for escaping helper 'h()'
      include ERB::Util
      # For route path helpers
      include OpenProject::ObjectLinking
      include OpenProject::StaticRouting::UrlHelpers
      # Rails helper
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::TextHelper
      include ActionView::Helpers::UrlHelper

      def self.regexp
        # Hash and revision separators are split into separate alternation
        # branches so the semantic-id identifier shape only applies to `#`
        # references — `r` revisions stay numeric-only. Splitting them shifts
        # the colon-separator group indices; `parse_match` is the single
        # place that maps regex group numbers to semantic field names.
        semantic_id = WorkPackage::SemanticIdentifier::ID_ROUTE_CONSTRAINT.source
        %r{
          ([[[:space:]](,~\-\[>]|^) # Leading string                                        [1]
          (!)? # Escaped marker                                                             [2]
          (([a-z0-9\-_]+):)? # Project identifier wrapper [3] + identifier                  [4]
          (#{allowed_prefixes.join('|')})? # prefix                                         [5]
          (                                                                                 # [6] outer
            (\#+)(#{semantic_id}) # hash sep [7] + identifier (numeric or semantic)         [8]
            |
            (r)(\d+) # revision sep [9] + numeric identifier                                [10]
            |
            (:) # colon separator                                                           [11]
            (                                                                               # [12] non-quoted-or-quoted
              [^"\s<>][^\s<>]*? # And a non-quoted value
              |
              "([^"]+)" # Or a quoted value                                                 [13]
            )
          )
          (?=
            (?=
              [[:punct:]]\W # Includes matches of, e.g., source:foo.ext
            )
            |\.\z # Allow matching when string ends with .
            |, # or with ,
            |~ # or with ~
            |\) # or with )
            |[[:space:]]
            |\]
            |<
            |$
           )
        }x
      end

      ##
      # Allowed prefix matchers
      def self.allowed_prefixes
        link_handlers
          .map(&:allowed_prefixes)
          .flatten
          .uniq
      end

      ##
      # Link handlers, may be extended by plugins
      def self.link_handlers
        [
          LinkHandlers::WorkPackages,
          LinkHandlers::HashSeparator,
          LinkHandlers::ColonSeparator,
          LinkHandlers::Revisions
        ]
      end

      # Reader for the link handler. Returns the preloaded WorkPackage for the
      # given identifier (numeric id as Integer or String, or semantic shape
      # like "PROJ-7"), or nil if no preload is active (classic mode, no `#N`
      # references in the doc, or pipeline path that bypasses
      # `with_preloaded_resources`) or the WP couldn't be resolved.
      def self.work_package_for(identifier)
        RequestStore.store[WORK_PACKAGES_LOOKUP_KEY]&.[](identifier.to_s)
      end

      # Doc-level preload (called by `PatternMatcherFilter` around the per-node
      # loop). Yields with the WP lookup populated, save/restoring on entry
      # and exit so nested `format_text` calls — which can happen when a
      # custom-field formatter or recursive markdown render re-enters the
      # pipeline mid-iteration — don't clobber the outer render's lookup.
      #
      # Skipped entirely in classic mode: `display_id` and `formatted_id`
      # collapse to the numeric form, so the link handler renders the legacy
      # shape from `wp_id` alone — no DB load required, matching pre-PR
      # behaviour. The yield-without-preload branch keeps the contract
      # uniform regardless of mode.
      #
      # Visibility filtering is intentionally NOT applied. The matcher links
      # regardless of viewer permissions — pre-existing behaviour outside
      # this ticket's scope.
      def self.with_preloaded_resources(doc, _context)
        # Capture the prior lookup unconditionally as the very first statement
        # so `ensure` can always restore it without a `defined?` guard,
        # regardless of which early-return branch we take.
        previous = RequestStore.store[WORK_PACKAGES_LOOKUP_KEY]

        return yield unless Setting::WorkPackageIdentifier.semantic_mode_active?

        identifiers = collect_work_package_identifiers(doc)
        return yield if identifiers.empty?

        RequestStore.store[WORK_PACKAGES_LOOKUP_KEY] = build_lookup(identifiers)
        yield
      ensure
        RequestStore.store[WORK_PACKAGES_LOOKUP_KEY] = previous
      end

      def self.collect_work_package_identifiers(doc)
        identifiers = Set.new
        doc.search(".//text()").each do |node|
          next if OpenProject::TextFormatting::PreformattedBlocks.ancestor?(node)

          node.to_s.scan(regexp) do
            extract_work_package_identifier(Regexp.last_match)&.then { identifiers << it }
          end
        end
        identifiers
      end

      # Returns the WP identifier string for any `#N` / `##N` / `###N` (or
      # semantic-shape) reference the WP link handler will try to render —
      # `#PROJ-1` plain links need the WP record for the `formatted_id`
      # label and hover-card URL; `##PROJ-1` / `###PROJ-1` quickinfo macros
      # use it to emit the user-facing `display_id` in `data-id`. Returns
      # nil for prefixed resource links (`version#3`, `message#12`),
      # `:`-separator resources, and leading-zero numerics we don't link.
      def self.extract_work_package_identifier(match)
        parts = parse_match(match)
        identifier = parts[:identifier]
        return nil unless parts[:prefix].nil? && parts[:sep]&.start_with?("#") && identifier.present?

        # Accept either the semantic shape (PROJ-7) or a numeric round-trip
        # (rejecting leading-zero "0123" forms that hit the regex's numeric
        # branch but aren't valid PK references).
        return nil unless WorkPackage::SemanticIdentifier.semantic_id?(identifier) ||
          identifier == identifier.to_i.to_s

        identifier
      end

      # Builds the per-render WP cache from a Set of identifier strings (mixed
      # numeric and semantic).
      #
      # Step 1 — `where_display_id_in` resolves all references in one SELECT
      # via id-IN / current-identifier-IN / alias-EXISTS. Rows index by
      # `id.to_s` and `identifier` (the WP's *current* slug).
      #
      # Step 2 — any input still unmapped after Step 1 must have matched via
      # the alias EXISTS subquery, since the loaded row only carries the
      # current identifier. One targeted `WorkPackageSemanticAlias` lookup
      # fills those mappings in. Skipped when no historical aliases are
      # referenced — the common case stays at 1 SELECT.
      def self.build_lookup(identifiers)
        work_packages = WorkPackage.where_display_id_in(identifiers).select(:id, :identifier).to_a
        lookup = index_by_id_and_identifier(work_packages)
        fold_in_alias_keys(lookup, identifiers, work_packages)
        lookup
      end

      def self.index_by_id_and_identifier(work_packages)
        work_packages.each_with_object({}) do |wp, lookup|
          lookup[wp.id.to_s] = wp
          lookup[wp.identifier] = wp if wp.identifier.present?
        end
      end
      private_class_method :index_by_id_and_identifier

      def self.fold_in_alias_keys(lookup, identifiers, work_packages)
        unmapped = identifiers.map(&:to_s) - lookup.keys
        return if unmapped.empty?

        wps_by_id = work_packages.index_by(&:id)
        WorkPackageSemanticAlias
          .where(identifier: unmapped)
          .pluck(:identifier, :work_package_id)
          .each { |ident, wp_id| lookup[ident] = wps_by_id[wp_id] }
      end
      private_class_method :fold_in_alias_keys

      # Single source of truth for which regex group means what. Both
      # `process_match` and `extract_work_package_identifier` consume this —
      # change the regex layout in `regexp` and only this site needs to follow.
      def self.parse_match(match)
        {
          leading: match[1],
          escaped: match[2],
          project_prefix: match[3],
          project_identifier: match[4],
          prefix: match[5],
          sep: match[7] || match[9] || match[11],
          raw_identifier: match[8] || match[10] || match[12],
          identifier: match[8] || match[10] || match[13] || match[12]
        }
      end

      def self.process_match(m, matched_string, context)
        instance = new(matched_string:, context:, **parse_match(m))
        instance.process
      end

      attr_reader :leading,
                  :matched_string,
                  :escaped,
                  :project_prefix,
                  :project_identifier,
                  :project,
                  :prefix,
                  :sep,
                  :identifier,
                  :raw_identifier,
                  :link,
                  :context

      def initialize(matched_string:,
                     leading:,
                     escaped:,
                     project_prefix:,
                     project_identifier:,
                     prefix:,
                     sep:,
                     raw_identifier:,
                     identifier:,
                     context:)
        super()
        # The entire string that was matched
        @matched_string = matched_string
        # Leading string before the link match
        @leading = leading
        # Catches the (!) to disable the parsing of this lnk
        @escaped = escaped
        # Project prefix (?)
        @project_prefix = project_prefix
        # Project identifier for context
        @project_identifier = project_identifier
        # Prefix (r? for revisions)
        @prefix = prefix
        # Separator(:)
        @sep = sep
        # Identifier with quotes (if any)
        @raw_identifier = raw_identifier
        # Identifier of the object with removed quotes (if any)
        @identifier = identifier
        # Text formatting context
        @context = context

        # Override project context for this match
        @project =
          if project_identifier
            Project.visible.find_by(identifier: project_identifier)
          else
            context[:project]
          end
      end

      ##
      # Process the matched string, returning either a link provided by a formatter,
      # or the matched string (minus escaping, if any) if no handler matches, an error occurred,
      # or the string was escaped.
      def process
        @link = nil

        # Allow handling when not escaped
        unless escaped?
          link_from_match
        end

        result
      end

      ##
      # Whether the matched string contains the escape marker (!) , e.g., `!#1234`.
      def escaped?
        @escaped.present?
      end

      private

      ##
      # Build a matching link by asking all handlers
      def link_from_match
        self.class.link_handlers.each do |klazz|
          handler = klazz.new(self, context:)

          if handler.applicable?
            @link = handler.call
            break
          end
        end
      rescue StandardError => e
        Rails.logger.error "Failed link resource handling for #{matched_string}: #{e}"
        Rails.logger.debug { "Backtrace:\n\t#{e.backtrace.join("\n\t")}" }
        # Keep the original string unmatched
        @link = nil
      end

      ##
      # build resulting link
      def result
        leading + (link || "#{project_prefix}#{prefix}#{sep}#{raw_identifier}")
      end
    end
  end
end
