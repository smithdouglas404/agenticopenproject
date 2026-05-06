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

require "spec_helper"
require_module_spec_helper

RSpec.describe Wikis::Adapters::Providers::XWiki::PageReference do
  describe ".parse" do
    it "parses a standard identifier" do
      ref = described_class.parse("xwiki:Main.WebHome")
      expect(ref).to have_attributes(wiki: "xwiki", spaces: ["Main"], page: "WebHome")
    end

    it "parses a nested space identifier" do
      ref = described_class.parse("xwiki:MySpace.SubSpace.PageName")
      expect(ref).to have_attributes(wiki: "xwiki", spaces: %w[MySpace SubSpace], page: "PageName")
    end

    it "returns nil when there is no colon separator" do
      expect(described_class.parse("Main.WebHome")).to be_nil
    end

    it "returns nil when the page path is blank" do
      expect(described_class.parse("xwiki:")).to be_nil
    end

    it "returns nil when there is no space segment" do
      expect(described_class.parse("xwiki:WebHome")).to be_nil
    end
  end

  describe "#rest_path" do
    it "builds a single-space path" do
      ref = described_class.parse("xwiki:Main.WebHome")
      expect(ref.rest_path).to eq("/wikis/xwiki/spaces/Main/pages/WebHome")
    end

    it "builds a nested-space path" do
      ref = described_class.parse("xwiki:MySpace.SubSpace.PageName")
      expect(ref.rest_path).to eq("/wikis/xwiki/spaces/MySpace/spaces/SubSpace/pages/PageName")
    end

    it "percent-encodes special characters in segments" do
      ref = described_class.parse("xwiki:My Space.My Page")
      expect(ref.rest_path).to eq("/wikis/xwiki/spaces/My%20Space/pages/My%20Page")
    end
  end
end
