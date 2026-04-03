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

RSpec.describe "script/i18n/merge_generated_locale_conflicts" do # rubocop:disable RSpec/DescribeClass
  let(:script_path) { Rails.root.join("script/i18n/merge_generated_locale_conflicts") }
  let(:merger) { instance_double(OpenProject::GeneratedLocaleConflictMerger, call: result) }

  before do
    allow(OpenProject::GeneratedLocaleConflictMerger).to receive(:new).and_return(merger)
  end

  context "when all generated conflicts were resolved" do
    let(:result) do
      OpenProject::GeneratedLocaleConflictMerger::Result.new(
        resolved_files: ["config/locales/crowdin/es.yml"],
        unresolved_files: [],
        non_generated_files: []
      )
    end

    it "exits successfully" do
      expect { load script_path }.not_to raise_error
    end
  end

  context "when non-generated conflicts remain but all generated are resolved" do
    let(:result) do
      OpenProject::GeneratedLocaleConflictMerger::Result.new(
        resolved_files: ["config/locales/crowdin/es.yml"],
        unresolved_files: [],
        non_generated_files: ["docs/api/apiv3/openapi-spec.yml"]
      )
    end

    it "exits successfully" do
      expect { load script_path }.not_to raise_error
    end
  end

  context "when generated conflicts remain unresolved" do
    let(:result) do
      OpenProject::GeneratedLocaleConflictMerger::Result.new(
        resolved_files: [],
        unresolved_files: ["config/locales/crowdin/es.yml"],
        non_generated_files: []
      )
    end

    it "exits with status 2" do
      expect { load script_path }
        .to raise_error(SystemExit) { |error| expect(error.status).to eq(2) }
    end
  end
end
