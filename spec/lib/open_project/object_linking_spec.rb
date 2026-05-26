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

RSpec.describe OpenProject::ObjectLinking, type: :helper do
  describe "#link_to_user" do
    let(:user) { build_stubbed(:user) }

    context "when given a non-User object" do
      it "returns a span with the object's string representation" do
        result = helper.link_to_user("some string")
        expect(result).to have_css("span", text: "some string")
      end
    end

    context "when given a locked user and current user is not admin" do
      let(:user) { build_stubbed(:user, :locked) }

      before { allow(User.current).to receive(:admin?).and_return(false) }

      it "returns a span with the user's name" do
        result = helper.link_to_user(user)
        expect(result).to have_css("span", text: user.name)
      end
    end

    context "when given an active user" do
      it "renders a link to the user's profile" do
        result = helper.link_to_user(user)
        expect(result).to have_css("a[href*='/users/#{user.id}']", text: user.name)
      end

      it "includes hover card data attributes" do
        result = helper.link_to_user(user)
        expect(result).to have_css("a[data-hover-card-url]")
        expect(result).to have_css("a[data-hover-card-trigger-target='trigger']")
      end
    end

    context "when given a locked user and current user is admin" do
      let(:user) { build_stubbed(:user, :locked) }

      before { allow(User.current).to receive(:admin?).and_return(true) }

      it "still renders a link to the user's profile" do
        result = helper.link_to_user(user)
        expect(result).to have_css("a[href*='/users/#{user.id}']")
      end
    end
  end

  describe "#link_to_group" do
    let(:group) { build_stubbed(:group) }

    context "when given a non-Group object" do
      it "returns a span with the object's string representation" do
        result = helper.link_to_group("not a group")
        expect(result).to have_css("span", text: "not a group")
      end
    end

    context "when given a group" do
      it "renders a link to the group page" do
        result = helper.link_to_group(group)
        expect(result).to have_css("a[href*='/groups/#{group.id}']", text: group.name)
      end

      it "includes a title attribute" do
        result = helper.link_to_group(group)
        expect(result).to have_css("a[title]")
      end
    end
  end
end
