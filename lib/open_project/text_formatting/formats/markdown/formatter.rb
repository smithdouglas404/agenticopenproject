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

module OpenProject::TextFormatting::Formats::Markdown
  class Formatter < OpenProject::TextFormatting::Formats::BaseFormatter
    # html-pipeline 3.x runs all NodeFilters in a single Selma streaming pass,
    # which means:
    #   - HTML inserted by one filter is NOT re-processed by other filters in the same pass.
    #   - The Selma sanitizer runs before handler callbacks, so it can strip attributes
    #     (e.g. bare-filename img.src) before filters like AttachmentFilter can act on them.
    #
    # We therefore split rendering into three sequential passes:
    #
    #   Pass 1 – convert:   markdown → HTML, prefix fragment IDs, collect TOC.
    #   Pass 2 – content:   attachment lookup, task lists, figure wrapping, macros,
    #                        mentions, pattern matching, syntax highlighting, auto-linking.
    #                        No sanitization so AttachmentFilter sees the original img.src.
    #   Post-process:       Nokogiri walk to add op-uc-list_task-list class to <ul>
    #                        elements that contain task-list checkboxes (streaming cannot
    #                        look back at a parent element).
    #   Pass 3 – attribute: sanitize, apply BEM CSS classes, add link attributes.
    #                        Runs on the fully-expanded HTML so BemCssFilter and
    #                        LinkAttributeFilter see elements inserted by earlier passes.

    def to_html(text)
      # Pass 1: markdown → HTML + collect TOC
      pass1 = build_convert_pipeline.call(text, context:)
      html  = pass1[:output].to_s
      toc   = pass1[:toc]

      # Pass 2: content modifications (no sanitization, toc available via context)
      html = build_content_pipeline(toc:).call(html, context: context.merge(toc:))[:output].to_s

      # Post-process: add task-list class to <ul> elements with checkboxes
      html = add_task_list_ul_classes(html)

      # Pass 3: sanitize + BEM CSS + link attributes
      build_attribute_pipeline.call(html, context:)[:output].html_safe
    end

    def self.format
      :markdown
    end

    private

    # ---------------------------------------------------------------------------
    # Pipeline builders – each call returns a fresh HTMLPipeline with fresh
    # filter instances so state never leaks between to_html invocations.
    # ---------------------------------------------------------------------------

    def build_convert_pipeline
      HTMLPipeline.new(
        text_filters:    [OpenProject::TextFormatting::Filters::SettingMacrosFilter.new],
        convert_filter:  OpenProject::TextFormatting::Filters::MarkdownFilter.new,
        node_filters:    [
          OpenProject::TextFormatting::Filters::SanitizationFilter::FragmentIdPrefixFilter.new,
          OpenProject::TextFormatting::Filters::TableOfContentsFilter.new
        ],
        sanitization_config: nil,
        default_context: context
      )
    end

    def build_content_pipeline(toc: nil)
      HTMLPipeline.new(
        text_filters:    [],
        convert_filter:  nil,
        node_filters:    [
          OpenProject::TextFormatting::Filters::AttachmentFilter.new(context: context.merge(toc:)),
          OpenProject::TextFormatting::Filters::TaskListFilter.new,
          OpenProject::TextFormatting::Filters::FigureWrappedFilter.new,
          OpenProject::TextFormatting::Filters::MacroFilter.new,
          OpenProject::TextFormatting::Filters::MentionFilter.new,
          OpenProject::TextFormatting::Filters::PatternMatcherFilter.new,
          OpenProject::TextFormatting::Filters::SyntaxHighlightFilter.new,
          OpenProject::TextFormatting::Filters::AutolinkFilter.new,
          OpenProject::TextFormatting::Filters::AutolinkCustomProtocolsFilter.new,
          OpenProject::TextFormatting::Filters::RelativeLinkFilter.new
        ],
        sanitization_config: nil,
        default_context: context.merge(toc:)
      )
    end

    def build_attribute_pipeline
      HTMLPipeline.new(
        text_filters:    [],
        convert_filter:  nil,
        node_filters:    [
          OpenProject::TextFormatting::Filters::LinkAttributeFilter.new,
          OpenProject::TextFormatting::Filters::ExternalLinkCaptureFilter.new,
          OpenProject::TextFormatting::Filters::BemCssFilter.new
        ],
        sanitization_config: OpenProject::TextFormatting::Filters::SanitizationFilter.config,
        default_context: context
      )
    end

    # ---------------------------------------------------------------------------
    # Nokogiri post-processing: add op-uc-list_task-list to <ul> elements whose
    # direct <li> children contain a task-list checkbox, and remove empty <p>
    # elements that are adjacent to <figure> elements (produced when lol-html
    # auto-closes <p> upon encountering a block-level <figure> inside it).
    # Selma's streaming model does not allow a handler to look back at a parent
    # element, so we do this in a separate Nokogiri pass.
    # ---------------------------------------------------------------------------

    def add_task_list_ul_classes(html)
      return html if html.blank?

      doc = Nokogiri::HTML5.fragment(html)

      # Restructure task-list checkboxes: hoist any <input type="checkbox"> to be
      # the first child of its enclosing <li> (it may be wrapped in a <label> or
      # nested inside other inline elements from user-authored HTML).  Also add the
      # op-uc-list--task-checkbox class and strip op-uc-list__label__description
      # from sibling <span> elements so they render as plain spans.  The <label>
      # wrapper (if present) is removed later by the sanitizer in Pass 3.
      doc.css("li").each do |li|
        input = li.at_css("input[type='checkbox']")
        next unless input

        # Strip op-uc-list__label__description from all spans within this li
        li.css("span.op-uc-list__label__description").each { |s| s.remove_attribute("class") }

        # Ensure the task-checkbox class is present
        existing_class = input["class"]
        unless existing_class&.include?("op-uc-list--task-checkbox")
          input["class"] = [existing_class.presence, "op-uc-list--task-checkbox"].compact.join(" ")
        end

        # Hoist input to be the first child of li (skip if already there)
        li.prepend_child(input) unless input.parent.equal?(li) && input.previous_sibling.nil?
      end

      # Ensure ul elements that contain task-list checkboxes carry op-uc-list_task-list
      # as their first class (normalises class order for user-authored HTML that may
      # have the classes in a different order).
      doc.css("ul").each do |ul|
        has_checkbox = ul.css("> li > input[type='checkbox']").any?
        next unless has_checkbox

        existing_classes = ul["class"]&.split(/\s+/) || []
        existing_classes.delete("op-uc-list_task-list")
        ul["class"] = (["op-uc-list_task-list"] + existing_classes).join(" ")
      end

      # Restore <p> wrappers around block elements that lol-html auto-closes <p>
      # for when inserted inside it.  Patterns handled: <figure> (from
      # FigureWrappedFilter) and <nav> (from the TOC macro).
      # The pattern is: <p></p><block>...</block><p></p>
      # We move the block back inside the first <p> and remove the trailing <p>.
      doc.css("figure, nav").each do |block_el|
        prev_p = block_el.previous_sibling
        next_p = block_el.next_sibling

        next unless prev_p&.name == "p" &&
                    prev_p.text.strip.empty? && prev_p.element_children.empty? &&
                    next_p&.name == "p" &&
                    next_p.text.strip.empty? && next_p.element_children.empty?

        prev_p.add_child(block_el) # moves element inside prev_p
        next_p.remove
      end

      doc.to_xhtml
    end
  end
end
