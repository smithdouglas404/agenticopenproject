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

RSpec.describe OpenProject::JournalFormatter::AssociatedVersion do
  let(:journal) { instance_double(Journal, id: 1) }

  subject(:instance) { described_class.new(journal) }

  context "with a target_versions key" do
    let(:key) { "target_versions_42" }
    let(:label_html) { "<strong>#{WorkPackage.human_attribute_name(:target_versions)}</strong>" }
    let(:label_text) { WorkPackage.human_attribute_name(:target_versions) }

    describe "#render" do
      context "when a version is added (nil → name)" do
        it "renders an HTML added text" do
          result = instance.render(key, [nil, "Sprint 1"])
          expect(result).to eq(I18n.t(:text_journal_added, label: label_html, value: "<i>Sprint 1</i>"))
        end

        it "renders a plain-text added text" do
          result = instance.render(key, [nil, "Sprint 1"], html: false)
          expect(result).to eq(I18n.t(:text_journal_added, label: label_text, value: "Sprint 1"))
        end
      end

      context "when a version is removed (name → nil)" do
        it "renders an HTML removed text" do
          result = instance.render(key, ["Sprint 1", nil])
          expect(result).to eq(I18n.t(:text_journal_deleted,
                                      label: label_html,
                                      old: "<strike><i>Sprint 1</i></strike>"))
        end

        it "renders a plain-text removed text" do
          result = instance.render(key, ["Sprint 1", nil], html: false)
          expect(result).to eq(I18n.t(:text_journal_deleted, label: label_text, old: "Sprint 1"))
        end
      end
    end
  end

  context "with an observed_in_versions key" do
    let(:key) { "observed_in_versions_42" }
    let(:label_html) { "<strong>#{WorkPackage.human_attribute_name(:observed_in_versions)}</strong>" }
    let(:label_text) { WorkPackage.human_attribute_name(:observed_in_versions) }

    describe "#render" do
      context "when a version is added (nil → name)" do
        it "renders an HTML added text" do
          result = instance.render(key, [nil, "Sprint 1"])
          expect(result).to eq(I18n.t(:text_journal_added, label: label_html, value: "<i>Sprint 1</i>"))
        end

        it "renders a plain-text added text" do
          result = instance.render(key, [nil, "Sprint 1"], html: false)
          expect(result).to eq(I18n.t(:text_journal_added, label: label_text, value: "Sprint 1"))
        end
      end

      context "when a version is removed (name → nil)" do
        it "renders an HTML removed text" do
          result = instance.render(key, ["Sprint 1", nil])
          expect(result).to eq(I18n.t(:text_journal_deleted,
                                      label: label_html,
                                      old: "<strike><i>Sprint 1</i></strike>"))
        end

        it "renders a plain-text removed text" do
          result = instance.render(key, ["Sprint 1", nil], html: false)
          expect(result).to eq(I18n.t(:text_journal_deleted, label: label_text, old: "Sprint 1"))
        end
      end
    end
  end
end
