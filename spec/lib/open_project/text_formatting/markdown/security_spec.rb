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
require "spec_helper"

# These specs exist because cmark-gfm's :tagfilter extension is intentionally
# NOT enabled in MarkdownFilter (it is extremely slow on large inputs such as long tables).
# The same protection is provided by SanitizationFilter, which strips any tag
# not on its allowlist.
# This specs serves as an additional measure to test the specific tags part of tagfilter.
RSpec.describe "Markdown security (tagfilter-equivalent protections)" do # rubocop:disable RSpec/DescribeClass
  def to_html(markdown)
    OpenProject::TextFormatting::Renderer.format_text(markdown).to_s
  end

  # The 9 tags that cmark-gfm's :tagfilter extension targets.
  # https://github.github.com/gfm/#disallowed-raw-html-extension-
  %w[
    title textarea style xmp iframe noembed noframes script plaintext
  ].each do |tag|
    describe "raw <#{tag}> in markdown input" do
      it "does not produce a live <#{tag}> element in the output" do
        html = to_html("before <#{tag}>payload</#{tag}> after")
        expect(html).not_to match(/<#{tag}\b/i)
        expect(html).not_to match(%r{</#{tag}>}i)
      end

      it "does not produce a live <#{tag}> in an HTML block" do
        markdown = <<~MD
          paragraph one

          <#{tag}>payload</#{tag}>

          paragraph two
        MD
        html = to_html(markdown)
        expect(html).not_to match(/<#{tag}\b/i)
        expect(html).not_to match(%r{</#{tag}>}i)
      end

      it "strips uppercase <#{tag.upcase}> just the same" do
        html = to_html("x <#{tag.upcase}>payload</#{tag.upcase}> y")
        expect(html).not_to match(/<#{tag}\b/i)
      end

      it "strips <#{tag}> with attributes" do
        html = to_html(%(x <#{tag} id="a" class="b" data-x="c">payload</#{tag}> y))
        expect(html).not_to match(/<#{tag}\b/i)
      end
    end
  end

  describe "classic XSS payloads" do
    it "neutralises an inline <script> alert" do
      html = to_html("hello <script>alert('xss')</script> world")
      expect(html).not_to match(/<script\b/i)
      expect(html).not_to include("alert('xss')")
    end

    it "neutralises a <script src=...> external loader" do
      html = to_html(%(<script src="https://evil.example.com/x.js"></script>))
      expect(html).not_to match(/<script\b/i)
      expect(html).not_to include("evil.example.com")
    end

    it "neutralises an <iframe> pointing at javascript:" do
      html = to_html(%(<iframe src="javascript:alert(1)"></iframe>))
      expect(html).not_to match(/<iframe\b/i)
      expect(html).not_to match(/javascript:/i)
    end

    it "neutralises <iframe srcdoc=...> HTML injection" do
      html = to_html(%(<iframe srcdoc="<script>alert(1)</script>"></iframe>))
      expect(html).not_to match(/<iframe\b/i)
      expect(html).not_to match(/<script\b/i)
    end

    it "neutralises <style> CSS injection with url() data-exfil" do
      # The <style> element must be removed; the CSS `url()` cannot fire without
      # a surviving <style> wrapper. Any leftover URL text is no longer a CSS rule.
      html = to_html(%(<style>body { background: url('https://evil.example.com/?'); }</style>))
      expect(html).not_to match(/<style\b/i)
      expect(html).not_to match(%r{</style>}i)
    end

    it "neutralises <plaintext> document takeover" do
      markdown = <<~MD
        safe paragraph before

        <plaintext>everything from here should be hidden

        but we render a trailing paragraph too
      MD
      html = to_html(markdown)
      expect(html).not_to match(/<plaintext\b/i)
      expect(html).to include("safe paragraph before")
      expect(html).not_to include("everything from here should be hidden")
      expect(html).to include("trailing paragraph")
    end

    it "neutralises <title> document-title takeover" do
      html = to_html("<title>Attacker Title</title>")
      expect(html).not_to match(/<title\b/i)
    end

    it "neutralises <textarea> that would otherwise swallow following content" do
      markdown = <<~MD
        before

        <textarea>swallowed</textarea>

        after
      MD
      html = to_html(markdown)
      expect(html).not_to match(/<textarea\b/i)
      expect(html).to include("after")
    end

    it "neutralises <xmp> raw-text takeover" do
      markdown = <<~MD
        before

        <xmp><script>alert(1)</script></xmp>

        after
      MD
      html = to_html(markdown)
      expect(html).not_to match(/<xmp\b/i)
      expect(html).not_to match(/<script\b/i)
      expect(html).to include("after")
    end

    it "strips <img onerror=...> attribute-based XSS" do
      html = to_html(%(<img src="x" onerror="alert(1)">))
      expect(html).not_to include("onerror")
      expect(html).not_to include("alert(1)")
    end

    it "strips event-handler attributes on allowed tags" do
      html = to_html(%(<a href="https://example.com" onclick="alert(1)">link</a>))
      expect(html).to match(/<a\b/i)
      expect(html).not_to include("onclick")
      expect(html).not_to include("alert(1)")
    end

    it "strips javascript: protocol on <a href>" do
      html = to_html(%([click](javascript:alert(1))))
      expect(html).not_to match(/href="javascript:/i)
    end

    it "strips <object> and <embed> which are not on the allowlist" do
      html = to_html(%(<object data="https://evil.example.com/x.swf"></object><embed src="x.swf">))
      expect(html).not_to match(/<object\b/i)
      expect(html).not_to match(/<embed\b/i)
      expect(html).not_to include("evil.example.com")
    end

    it "strips inline SVG <script>" do
      html = to_html(%(<svg><script>alert(1)</script></svg>))
      expect(html).not_to match(/<script\b/i)
      expect(html).not_to include("alert(1)")
    end
  end

  describe "regression: disabling tagfilter does not regress existing behaviour" do
    it "still escapes a bare '<script>' text token in inline flow" do
      html = to_html("this is a <script>")
      expect(html).not_to match(/<script\b/i)
    end

    it "preserves non-dangerous HTML passthrough (e.g. <strong>)" do
      html = to_html("a <strong>bold</strong> word")
      expect(html).to match(%r{<strong>bold</strong>})
    end
  end
end
