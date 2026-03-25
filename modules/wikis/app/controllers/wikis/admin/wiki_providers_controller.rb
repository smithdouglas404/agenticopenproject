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

module Wikis
  module Admin
    class WikiProvidersController < ApplicationController
      include OpTurbo::ComponentStream

      layout "admin"

      before_action :require_admin
      before_action :find_wiki_provider, only: %i[edit update destroy confirm_destroy edit_general_info]

      menu_item :wiki_providers

      def index
        @wiki_providers = Wikis::Provider.all
      end

      def new
        @wiki_provider = Wikis::XWikiProvider.new
      end

      def edit; end

      def create
        @wiki_provider = Wikis::XWikiProvider.new(wiki_provider_params)

        if @wiki_provider.save
          flash[:notice] = I18n.t(:notice_successful_create)
          redirect_to edit_admin_settings_wiki_provider_path(@wiki_provider)
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @wiki_provider.update(wiki_provider_params)
          flash[:notice] = I18n.t(:notice_successful_update)
          redirect_to edit_admin_settings_wiki_provider_path(@wiki_provider)
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @wiki_provider.destroy!
        flash[:notice] = I18n.t(:notice_successful_delete)
        redirect_to admin_settings_wiki_providers_path
      end

      def confirm_destroy
        respond_with_dialog Wikis::Admin::DestroyConfirmationDialogComponent.new(wiki_provider: @wiki_provider)
      end

      def edit_general_info
        update_via_turbo_stream(component: Wikis::Admin::Forms::GeneralInfoFormComponent.new(@wiki_provider))
        respond_with_turbo_streams
      end

      private

      def find_wiki_provider
        @wiki_provider = Wikis::XWikiProvider.find(params[:id])
      end

      def wiki_provider_params
        params.expect(wikis_xwiki_provider: %i[name url])
      end
    end
  end
end
