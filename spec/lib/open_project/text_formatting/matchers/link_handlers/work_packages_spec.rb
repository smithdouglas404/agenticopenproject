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
require_relative "../../markdown/expected_markdown"

RSpec.describe OpenProject::TextFormatting::Matchers::LinkHandlers::WorkPackages do
  include_context "expected markdown modules"

  shared_let(:user) { create(:admin) }

  before { allow(User).to receive(:current).and_return(user) }

  # WP-table SELECTs from any helper invocation other than `format_text`
  # itself — model setup, current-user fetches, project preloads — must not
  # leak into the regression guard. Wrap only the rendering call.
  def work_package_selects_during(&)
    recorder = ActiveRecord::QueryRecorder.new(&)
    recorder.log.grep(/FROM "work_packages"/i)
  end

  describe "the `#N` numeric reference" do
    let(:rendered) { format_text("#1234") }

    it "renders an anchor with the typed identifier in both the label and href" do
      expect(rendered).to include(">#1234<")
      expect(rendered).to include(%(href="/work_packages/1234"))
    end

    it "does not issue any work_packages SELECTs" do
      selects = work_package_selects_during { format_text("#1234") }
      expect(selects).to be_empty
    end

    context "with a leading-zero numeric form" do
      it "stays as literal text (e.g. `#0123` does not resolve to WP 123)" do
        result = format_text("#0123")
        expect(result).to include("#0123")
        expect(result).not_to include(%(href="/work_packages/))
      end
    end
  end

  describe "the `#PROJ-N` semantic reference" do
    let(:rendered) { format_text("#PROJ-1") }

    it "renders an anchor with the typed identifier in both the label and href" do
      expect(rendered).to include(">#PROJ-1<")
      expect(rendered).to include(%(href="/work_packages/PROJ-1"))
    end

    it "does not issue any work_packages SELECTs (route resolves both shapes)" do
      selects = work_package_selects_during { format_text("#PROJ-1") }
      expect(selects).to be_empty
    end

    it "renders identically in classic and semantic mode (routing is mode-agnostic)" do
      Setting.work_packages_identifier = "classic"
      classic = format_text("#PROJ-1")

      Setting.work_packages_identifier = "semantic"
      semantic = format_text("#PROJ-1")

      expect(classic).to eq(semantic)
    end
  end

  describe "the `##PROJ-N` quickinfo reference" do
    it "emits an inline quickinfo macro element with the typed identifier" do
      # Prepend "see " so Markly doesn't parse `##…` as an H2 ATX heading.
      rendered = format_text("see ##PROJ-1 here")

      expect(rendered).to include(%(<opce-macro-wp-quickinfo data-id="PROJ-1" data-detailed="false">))
    end

    it "emits a detailed quickinfo macro element for `###PROJ-N`" do
      rendered = format_text("see ###PROJ-1 here")

      expect(rendered).to include(%(<opce-macro-wp-quickinfo data-id="PROJ-1" data-detailed="true">))
    end

    it "issues no work_packages SELECTs" do
      selects = work_package_selects_during { format_text("see ##PROJ-1 and ###PROJ-2 here") }
      expect(selects).to be_empty
    end
  end

  describe "prefixed `version#…` references" do
    it "does not query the versions table when the identifier is semantic-shaped" do
      recorder = ActiveRecord::QueryRecorder.new { format_text("see version#PROJ-1 here") }
      version_selects = recorder.log.grep(/FROM "versions"/i)
      expect(version_selects).to be_empty
    end
  end
end
