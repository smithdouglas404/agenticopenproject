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
    class PatternMatcherFilter < HTML::Pipeline::Filter
      # Skip text nodes that are within preformatted blocks
      PREFORMATTED_BLOCKS = %w(pre code).to_set

      class << self
        def append_matcher(matcher)
          matchers << matcher
        end

        def matchers
          @matchers ||= []
        end
      end

      def call
        with_matcher_preloads(self.class.matchers.dup) { process_text_nodes }
        doc
      end

      private

      # Recursively wraps the per-node loop in each matcher's
      # `with_preloaded_resources` block (a yielding hook). This lets matchers
      # warm per-render caches AND save/restore the previous state, so nested
      # `format_text` calls — e.g. a custom-field formatter that re-enters the
      # pipeline mid-render — don't clobber the outer render's lookup. Opt-in:
      # matchers without the hook are skipped.
      def with_matcher_preloads(matchers, &)
        matcher = matchers.shift
        return yield if matcher.nil?

        if matcher.respond_to?(:with_preloaded_resources)
          matcher.with_preloaded_resources(doc, context) { with_matcher_preloads(matchers, &) }
        else
          with_matcher_preloads(matchers, &)
        end
      end

      def process_text_nodes
        doc.search(".//text()").each do |node|
          next if has_ancestor?(node, PREFORMATTED_BLOCKS)

          self.class.matchers.each do |matcher|
            matcher.call(node, doc:, context:)
          end
        end
      end
    end
  end
end
