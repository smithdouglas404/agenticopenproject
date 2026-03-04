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

RSpec.describe OpenProject::Identifier do
  describe ".semantic_id?" do
    context "with string inputs that are just integers" do
      it "returns false for string '123'" do
        expect(described_class.semantic_id?("123")).to be false
      end

      it "returns false for string '0'" do
        expect(described_class.semantic_id?("0")).to be false
      end
    end

    context "with string inputs that are not just integers" do
      it "returns true for string 'my-project'" do
        expect(described_class.semantic_id?("my-project")).to be true
      end

      it "returns true for string 'project-123'" do
        expect(described_class.semantic_id?("project-123")).to be true
      end
    end

    context "with integer inputs" do
      it "returns false for integer 123" do
        expect(described_class.semantic_id?(123)).to be false
      end

      it "returns false for integer 0" do
        expect(described_class.semantic_id?(0)).to be false
      end
    end

    context "with nil" do
      it "returns true" do
        expect(described_class.semantic_id?(nil)).to be true
      end
    end
  end

  describe ".database_id?" do
    context "with string inputs that are just integers" do
      it "returns true for string '123'" do
        expect(described_class.database_id?("123")).to be true
      end

      it "returns true for string '0'" do
        expect(described_class.database_id?("0")).to be true
      end
    end

    context "with string inputs that are not just integers" do
      it "returns false for string 'my-project'" do
        expect(described_class.database_id?("my-project")).to be false
      end

      it "returns false for string 'project-123'" do
        expect(described_class.database_id?("project-123")).to be false
      end
    end

    context "with integer inputs" do
      it "returns true for integer 123" do
        expect(described_class.database_id?(123)).to be true
      end

      it "returns true for integer 0" do
        expect(described_class.database_id?(0)).to be true
      end
    end

    context "with nil" do
      it "returns false" do
        expect(described_class.database_id?(nil)).to be false
      end
    end
  end
end
