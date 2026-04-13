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

RSpec.describe Projects::Identifier do
  describe "identifier normalization" do
    subject { Project.new }

    it_behaves_like "strips invisible characters", :identifier
  end

  describe "url identifier" do
    let(:reserved) do
      Rails.application.routes.routes
        .map { |route| route.path.spec.to_s }
        .filter_map { |path| path[%r{^/projects/(\w+)\(\.:format\)$}, 1] }
        .uniq
    end

    it "is set from name" do
      project = Project.new(name: "foo")

      project.validate

      expect(project.identifier).to eq("foo")
    end

    it "is not allowed to clash with projects routing" do
      expect(reserved).not_to be_empty

      reserved.each do |word|
        project = Project.new(name: word)

        project.validate

        expect(project.identifier).not_to eq(word)
      end
    end

    it "is not allowed to clash with another project" do
      create(:project, identifier: "existing")

      project = build(:project, identifier: "existing")
      expect(project).not_to be_valid
      expect(project.errors[:identifier]).to include("has already been taken.")
    end

    it "is not allowed to clash with a former identifier of another project" do
      other_project = create(:project, identifier: "former-id")
      other_project.update!(identifier: "new-id")

      project = build(:project, identifier: "former-id")
      expect(project).not_to be_valid
      expect(project.errors[:identifier]).to include("has already been taken.")
    end

    it "is allowed to be the same as its own former identifier" do
      project = create(:project, identifier: "old-id")
      project.update!(identifier: "new-id")

      project.identifier = "old-id"
      expect(project).to be_valid
    end

    # The acts_as_url plugin defines validation callbacks on :create and it is not automatically
    # called when calling a custom context. However we need the acts_as_url callback to set the
    # identifier when the validations are called with the :saving_custom_fields context.
    context "when validating with :saving_custom_fields context" do
      it "is set from name" do
        project = Project.new(name: "foo")

        project.validate(:saving_custom_fields)

        expect(project.identifier).to eq("foo")
      end

      it "is not allowed to clash with projects routing" do
        expect(reserved).not_to be_empty

        reserved.each do |word|
          project = Project.new(name: word)

          project.validate(:saving_custom_fields)

          expect(project.identifier).not_to eq(word)
        end
      end
    end

    context "with history" do
      let!(:project) { create(:project, identifier: "sc") }

      it "records the old identifier in friendly_id_slugs when identifier changes" do
        project.update!(identifier: "scp")
        expect(FriendlyId::Slug.where(sluggable: project).pluck(:slug)).to include("sc")
      end

      it "can still find the project via its old identifier" do
        project.update!(identifier: "scp")
        expect(Project.friendly.find("sc")).to eq(project)
      end

      it "returns the project with its current identifier when found via old identifier" do
        project.update!(identifier: "scp")
        found = Project.friendly.find("sc")
        expect(found.identifier).to eq("scp")
      end

      it "locks old identifier to the original project (not reusable by others)" do
        project.update!(identifier: "scp")
        slug = FriendlyId::Slug.find_by(slug: "sc")
        expect(slug.sluggable_id).to eq(project.id)
      end

      it "allows the project to revert to a previously used identifier" do
        project.update!(identifier: "scp")
        expect { project.update!(identifier: "sc") }.not_to raise_error
        expect(project.identifier).to eq("sc")
      end

      it "is valid when reverting to own historical identifier" do
        project.update!(identifier: "scp")
        project.identifier = "sc"
        expect(project).to be_valid
      end
    end
  end

  describe ".suggest_identifier" do
    context "with alphanumeric identifiers", with_settings: { work_packages_identifier: "alphanumeric" } do
      it "delegates to ProjectIdentifierSuggestionGenerator" do
        allow(WorkPackages::IdentifierAutofix::ProjectIdentifierSuggestionGenerator)
          .to receive(:suggest_identifier).with("My Project").and_return("MP")
        expect(Project.suggest_identifier("My Project")).to eq("MP")
        expect(WorkPackages::IdentifierAutofix::ProjectIdentifierSuggestionGenerator)
          .to have_received(:suggest_identifier).with("My Project")
      end
    end

    context "with numeric (legacy) identifiers", with_settings: { work_packages_identifier: "numeric" } do
      it "returns a slugified lowercase identifier" do
        expect(Project.suggest_identifier("My Cool Project")).to eq("my-cool-project")
      end
    end
  end
end
