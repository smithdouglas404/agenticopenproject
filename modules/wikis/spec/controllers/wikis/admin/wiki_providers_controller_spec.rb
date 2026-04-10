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
    let!(:wiki_provider) { create(:xwiki_provider) }

    it "renders the index template and assigns providers" do
      get :index
      expect(response).to be_successful
      expect(response).to render_template :index
      expect(assigns(:wiki_providers)).to include(wiki_provider)
    end

    context "when not admin" do
      before { login_as non_admin }

      it "responds with an error" do
        get :index
        expect(response).not_to be_successful
      end
    end
  end

  describe "GET #new" do
    it "renders the new template with an unpersisted provider" do
      get :new
      expect(response).to be_successful
      expect(response).to render_template :new
      expect(assigns(:wiki_provider)).to be_a(Wikis::XWikiProvider)
      expect(assigns(:wiki_provider)).not_to be_persisted
    end
  end

  describe "GET #edit" do
    let(:wiki_provider) { create(:xwiki_provider) }

    it "renders the edit template" do
      get :edit, params: { id: wiki_provider.id }
      expect(response).to be_successful
      expect(response).to render_template :edit
      expect(assigns(:wiki_provider)).to eq(wiki_provider)
    end
  end

  describe "POST #create" do
    let(:valid_params) { { wikis_xwiki_provider: { name: "My XWiki", url: "https://xwiki.example.com" } } }
    let(:invalid_params) { { wikis_xwiki_provider: { name: "", url: "https://xwiki.example.com" } } }

    context "with valid params" do
      it "creates a provider and redirects to edit" do
        expect { post :create, params: valid_params }
          .to change(Wikis::XWikiProvider, :count).by(1)
        expect(response).to redirect_to(edit_admin_settings_wiki_provider_path(Wikis::XWikiProvider.last))
        expect(flash[:notice]).to eq(I18n.t(:notice_successful_create))
      end
    end

    context "with invalid params" do
      it "re-renders the new template" do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template :new
      end
    end
  end

  describe "PATCH #update" do
    let(:wiki_provider) { create(:xwiki_provider) }
    let(:valid_params) { { id: wiki_provider.id, wikis_xwiki_provider: { name: "Updated XWiki" } } }

    context "with valid params" do
      it "updates the provider and redirects to edit" do
        patch :update, params: valid_params
        expect(wiki_provider.reload.name).to eq("Updated XWiki")
        expect(response).to redirect_to(edit_admin_settings_wiki_provider_path(wiki_provider))
        expect(flash[:notice]).to eq(I18n.t(:notice_successful_update))
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:wiki_provider) { create(:xwiki_provider) }

    it "deletes the provider and redirects to index" do
      expect { delete :destroy, params: { id: wiki_provider.id } }
        .to change(Wikis::XWikiProvider, :count).by(-1)
      expect(response).to redirect_to(admin_settings_wiki_providers_path)
      expect(flash[:notice]).to eq(I18n.t(:notice_successful_delete))
    end
  end

  describe "GET #confirm_destroy" do
    let(:wiki_provider) { create(:xwiki_provider) }

    it "responds with a turbo stream dialog" do
      get :confirm_destroy, params: { id: wiki_provider.id }, format: :turbo_stream
      expect(response).to be_successful
      expect(assigns(:wiki_provider)).to eq(wiki_provider)
    end
  end

  describe "GET #edit_general_info" do
    let(:wiki_provider) { create(:xwiki_provider) }

    it "responds with a turbo stream replacing the general info section" do
      get :edit_general_info, params: { id: wiki_provider.id }, format: :turbo_stream
      expect(response).to be_successful
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(assigns(:wiki_provider)).to eq(wiki_provider)
    end
  end
end
