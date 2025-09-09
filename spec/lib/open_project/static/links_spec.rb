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

RSpec.describe OpenProject::Static::Links do
  describe ".url_for" do
    subject { described_class.url_for(*args) }

    let(:args) { %i[enterprise_features board_view] }
    let(:locale_param) { "?go_to_locale=#{I18n.locale}" }

    it "resolves the URL stored in the href with a locale" do
      expect(subject)
        .to eq("https://www.openproject.org/docs/user-guide/agile-boards/#{locale_param}#action-boards-enterprise-add-on")
    end

    context "with german locale" do
      before do
        I18n.locale = :de
      end

      it "resolves the URL stored in the href with a locale" do
        expect(subject)
          .to eq("https://www.openproject.org/docs/user-guide/agile-boards/#{locale_param}#action-boards-enterprise-add-on")
      end
    end

    context "with docs URLs" do
      let(:args) { %i[sysadmin_docs oidc] }

      it "adds locale parameter to docs URLs" do
        expect(subject)
          .to eq("https://www.openproject.org/docs/system-admin-guide/authentication/openid-providers/#{locale_param}")
      end
    end

    context "with non-docs URLs" do
      let(:args) { %i[website] }

      it "does not add locale parameter to non-docs URLs" do
        expect(subject).to eq("https://www.openproject.org")
        expect(subject).not_to include("go_to_locale=")
      end
    end
  end

  describe ".docs_url?" do
    subject { described_class.docs_url?(url) }

    context "with docs URLs" do
      let(:url) { "https://www.openproject.org/docs/user-guide/agile-boards/" }

      it "returns true for URLs that start with the docs base URL" do
        expect(subject).to be true
      end
    end

    context "with non-docs URLs" do
      let(:url) { "https://www.openproject.org/enterprise-edition" }

      it "returns false for URLs that do not start with the docs base URL" do
        expect(subject).to be false
      end
    end
  end

  describe ".with_locale_param" do
    subject { described_class.with_locale_param(href) }

    let(:href) { "https://www.openproject.org/docs/system-admin-guide/authentication/openid-providers/" }

    before do
      allow(I18n).to receive(:locale).and_return(:en)
    end

    it "adds go_to_locale parameter to the URL" do
      expect(subject).to include("go_to_locale=en")
    end

    it "preserves the original URL structure" do
      expect(subject).to start_with(href)
    end

    context "with URL that already has query parameters" do
      let(:href) { "https://www.openproject.org/docs/user-guide/agile-boards/?section=boards" }

      it "adds go_to_locale parameter while preserving existing parameters" do
        expect(subject).to include("section=boards")
        expect(subject).to include("go_to_locale=en")
      end
    end

    context "with different locale" do
      before do
        allow(I18n).to receive(:locale).and_return(:de)
      end

      it "uses the current I18n locale" do
        expect(subject).to include("go_to_locale=de")
      end
    end
  end

  describe ".docs_url" do
    subject { described_class.docs_url }

    it "returns the base docs URL" do
      expect(subject).to eq("https://www.openproject.org/docs/")
    end
  end
end
