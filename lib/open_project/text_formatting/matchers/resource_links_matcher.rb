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
        %r{
          ([[[:space:]](,~\-\[>]|^) # Leading string
          (!)? # Escaped marker
          (([a-z0-9\-_]+):)? # Project identifier
          (#{allowed_prefixes.join('|')})? # prefix
          (
            (\#+|r)(\d+) # separator and its identifier
            |
            (:) # or colon separator
            (
              [^"\s<>][^\s<>]*? # And a non-quoted value [10]
              |
              "([^"]+)" # Or a quoted value [11]
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
      # given numeric id, or nil if no preload is active (e.g. classic mode,
      # no `#N` references in the doc, or pipeline path that bypasses
      # `with_preloaded_resources`).
      def self.work_package_for(id)
        RequestStore.store[WORK_PACKAGES_LOOKUP_KEY]&.[](id)
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
        return yield unless Setting::WorkPackageIdentifier.semantic_mode_active?

        ids = collect_work_package_ids(doc)
        return yield if ids.empty?

        previous = RequestStore.store[WORK_PACKAGES_LOOKUP_KEY]
        RequestStore.store[WORK_PACKAGES_LOOKUP_KEY] = WorkPackage.where(id: ids).index_by(&:id)
        yield
      ensure
        RequestStore.store[WORK_PACKAGES_LOOKUP_KEY] = previous if defined?(previous)
      end

      def self.collect_work_package_ids(doc)
        ids = Set.new
        doc.search(".//text()").each do |node|
          next if has_ancestor_in_preformatted_blocks?(node)

          node.to_s.scan(regexp) { extract_work_package_id(Regexp.last_match)&.then { |id| ids << id } }
        end
        ids
      end

      # Returns the numeric WP id for a `#N` plain link match, or nil for any
      # other shape (`##`/`###` quickinfo, prefixed `resource#id` links like
      # `version#3` / `message#12`, `:`-separator resources, or leading-zero
      # / non-numeric identifiers we don't link). The `prefix.nil?` guard
      # mirrors `LinkHandlers::WorkPackages#applicable?` so the preload set
      # only contains ids the WP handler will actually try to render.
      def self.extract_work_package_id(match)
        prefix = match[5]
        sep = match[7] || match[9]
        identifier = match[8] || match[11] || match[10]
        return nil unless prefix.nil? && sep == "#" && identifier.present? && identifier == identifier.to_i.to_s

        identifier.to_i
      end

      ##
      # Mirror of `PatternMatcherFilter::PREFORMATTED_BLOCKS` ancestry check —
      # `<pre>`/`<code>` text nodes are not matched, so they shouldn't
      # contribute to the preload set either.
      PREFORMATTED_ANCESTORS = %w[pre code].to_set
      def self.has_ancestor_in_preformatted_blocks?(node)
        ancestor = node.parent
        until ancestor.nil? || ancestor.fragment? || ancestor.document?
          return true if PREFORMATTED_ANCESTORS.include?(ancestor.name)

          ancestor = ancestor.parent
        end
        false
      end

      def self.process_match(m, matched_string, context)
        # Leading string before match
        instance = new(
          matched_string:,
          leading: m[1],
          escaped: m[2],
          project_prefix: m[3],
          project_identifier: m[4],
          prefix: m[5],
          sep: m[7] || m[9],
          raw_identifier: m[8] || m[10],
          identifier: m[8] || m[11] || m[10],
          context:
        )

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
