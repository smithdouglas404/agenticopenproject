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
# along with this program; if not, write to the GNU General Public
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"

RSpec.describe OpenProject::TextFormatting::Filters::SanitizationFilter do
  let(:context) { {} }

  def sanitize(html)
    filter = described_class.new(html, context)
    result = filter.call
    result.respond_to?(:to_html) ? result.to_html : result.to_s
  end

  describe "DOM clobbering prevention via fragment id prefix" do
    # id/name are prefixed with op-frag- so they cannot clobber document/window.
    # Anchors still work because fragment links are rewritten to use the same prefix.
    let(:prefix) { described_class::FRAGMENT_ID_PREFIX }

    context "when HTML contains id and name attributes" do
      it "prefixes name attribute so it cannot clobber" do
        html = '<p><img src="x" name="constructor" alt="" /></p>'
        output = sanitize(html)
        expect(output).not_to include('name="constructor"')
        expect(output).to include("name=\"#{prefix}constructor\"")
      end

      it "prefixes name on multiple elements" do
        html = '<p><img src="x" name="adoptNode" /><img src="x" name="getElementById" /></p>'
        output = sanitize(html)
        expect(output).to include("name=\"#{prefix}adoptNode\"")
        expect(output).to include("name=\"#{prefix}getElementById\"")
      end

      it "prefixes id attribute so it cannot clobber" do
        html = '<p><span id="constructor">text</span></p>'
        output = sanitize(html)
        expect(output).not_to include('id="constructor"')
        expect(output).to include("id=\"#{prefix}constructor\"")
      end

      it "does not double-prefix id or name" do
        html = "<p><span id=\"#{prefix}already\">x</span></p>"
        output = sanitize(html)
        expect(output).to include("id=\"#{prefix}already\"")
        expect(output).not_to include("id=\"#{prefix}#{prefix}")
      end
    end

    context "when HTML contains same-document fragment links" do
      it "rewrites href to use prefix so anchors match" do
        html = '<p><a href="#section">Jump</a></p>'
        output = sanitize(html)
        expect(output).to include("href=\"##{prefix}section\"")
      end

      it "does not rewrite empty fragment or full URLs" do
        html = '<p><a href="#">Top</a> <a href="https://example.com#anchor">External</a></p>'
        output = sanitize(html)
        expect(output).to include('href="#"')
        expect(output).to include('href="https://example.com#anchor"')
      end
    end

    context "when markdown produces a link with injected img tags (real-world payload)" do
      it "prefixes name attributes so they cannot clobber" do
        html = <<~HTML
          <p><a href="https://xyz.com">foobar</a><img src="x" name="constructor" /><img src="x" name="appendChild" /></p>
        HTML
        output = sanitize(html)
        expect(output).not_to match(/name=["']constructor["']/)
        expect(output).to include("name=\"#{prefix}constructor\"")
        expect(output).to include("name=\"#{prefix}appendChild\"")
      end
    end
  end
end
