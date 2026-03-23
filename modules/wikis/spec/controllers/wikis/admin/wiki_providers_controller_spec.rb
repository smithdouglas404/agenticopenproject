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

RSpec.describe Wikis::Admin::WikiProvidersController do
  let(:admin) { build(:admin) }
  let(:non_admin) { build(:user) }

  before { login_as admin }

  describe "GET #index" do
    it "renders the index template" do
      get :index
      expect(response).to be_successful
      expect(response).to render_template :index
    end

    it "assigns @wiki_providers" do
      get :index
      expect(assigns(:wiki_providers)).to eq([])
    end

    context "when not admin" do
      before { login_as non_admin }

      it "redirects to login" do
        get :index
        expect(response).not_to be_successful
      end
    end
  end

  describe "GET #new" do
    it "renders the new template" do
      get :new
      expect(response).to be_successful
      expect(response).to render_template :new
    end

    it "assigns a new wiki provider" do
      get :new
      expect(assigns(:wiki_provider)).to be_a(Wikis::XWikiProvider)
      expect(assigns(:wiki_provider)).not_to be_persisted
    end
  end

  describe "GET #edit" do
    it "renders the edit template" do
      get :edit, params: { id: 1 }
      expect(response).to be_successful
      expect(response).to render_template :edit
    end
  end

  describe "POST #create" do
    let(:valid_params) { { wikis_xwiki_provider: { name: "My XWiki", url: "https://xwiki.example.com" } } }

    it "redirects to index with a success notice" do
      post :create, params: valid_params
      expect(response).to redirect_to(admin_settings_wiki_providers_path)
      expect(flash[:notice]).to eq(I18n.t(:notice_successful_create))
    end
  end

  describe "PATCH #update" do
    let(:valid_params) { { id: 1, wikis_xwiki_provider: { name: "Updated XWiki", url: "https://xwiki.example.com" } } }

    it "redirects to edit with a success notice" do
      patch :update, params: valid_params
      expect(response).to redirect_to(edit_admin_settings_wiki_provider_path(id: 1))
      expect(flash[:notice]).to eq(I18n.t(:notice_successful_update))
    end
  end

  describe "DELETE #destroy" do
    it "redirects to index with a success notice" do
      delete :destroy, params: { id: 1 }
      expect(response).to redirect_to(admin_settings_wiki_providers_path)
      expect(flash[:notice]).to eq(I18n.t(:notice_successful_delete))
    end
  end
end
