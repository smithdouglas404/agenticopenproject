# frozen_string_literal: true

# -- copyright
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
# ++

require "spec_helper"

RSpec.describe PersistedQuery do
  shared_let(:user) { create(:user) }

  describe "STI" do
    let!(:project_query) { create(:project_query, user:) }

    it "stores the concrete class name in the type column" do
      expect(ProjectQuery.find(project_query.id).type).to eq("ProjectQuery")
    end

    it "scopes ProjectQuery to exclude other subclasses" do
      expect(ProjectQuery.count).to eq(1)
      expect(described_class.where(type: "OtherType").count).to eq(0)
    end

    it "stores and retrieves ProjectQuery via the shared table" do
      expect(described_class.find(project_query.id)).to be_a(ProjectQuery)
    end
  end

  describe "serialization coder binding" do
    it "binds filter coder to the concrete subclass, not PersistedQuery" do
      # If the coder binds to PersistedQuery, Queries::Register.filters[PersistedQuery]
      # would be empty and deserialization would always return [].
      coder = ProjectQuery.attribute_types["filters"].coder
      expect(coder).to be_a(Queries::Serialization::Filters)
      expect(coder.klass).to eq(ProjectQuery)
    end
  end

  describe "#changed and #changes exclude the type column" do
    let(:query) { ProjectQuery.new(user:, name: "test") }

    it "does not include type in #changed" do
      expect(query.changed).not_to include("type")
    end

    it "does not include type in #changes" do
      expect(query.changes).not_to have_key("type")
    end
  end

  describe "ordered_entities" do
    let!(:query) { create(:project_query, user:) }

    it "starts with no ordered entities" do
      expect(query.ordered_entities).to be_empty
    end

    it "destroys ordered entities when the query is destroyed" do
      other_user = create(:user)
      entity = query.ordered_entities.create!(entity_type: "User", entity_id: other_user.id, position: 1)

      expect { query.destroy }.to change(OrderedEntity, :count).by(-1)
      expect(OrderedEntity.exists?(entity.id)).to be(false)
    end

    it "returns entries ordered by position with nulls last" do
      other_user = create(:user)
      third_user = create(:user)
      query.ordered_entities.create!(entity_type: "User", entity_id: other_user.id, position: 2)
      query.ordered_entities.create!(entity_type: "User", entity_id: third_user.id, position: 1)

      expect(query.ordered_entities.pluck(:entity_id)).to eq([third_user.id, other_user.id])
    end
  end

  describe "acts_as_favoritable" do
    let!(:query) { create(:project_query, user:) }

    it "stores PersistedQuery as favorited_type and resolves to the correct subclass" do
      fav = Favorite.create!(user:, favorited: query)

      expect(fav.favorited_type).to eq("PersistedQuery")
      expect(fav.favorited).to eq(query)
    end
  end
end
