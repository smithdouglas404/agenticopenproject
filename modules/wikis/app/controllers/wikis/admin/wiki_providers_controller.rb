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
      layout "admin"

      before_action :require_admin
      before_action :find_wiki_provider, only: %i[edit update destroy confirm_destroy]

      menu_item :wiki_providers

      def index
        # TODO: load from database once data architecture (#72975) is complete
        @wiki_providers = []
      end

      def new
        @wiki_provider = Wikis::XWikiProvider.new
      end

      def create
        # TODO: persist via service once data architecture (#72975) is complete
        @wiki_provider = Wikis::XWikiProvider.new(wiki_provider_params)
        flash[:notice] = I18n.t(:notice_successful_create)
        redirect_to admin_settings_wiki_providers_path
      end

      def edit; end

      def update
        # TODO: persist via service once data architecture (#72975) is complete
        flash[:notice] = I18n.t(:notice_successful_update)
        redirect_to edit_admin_settings_wiki_provider_path(@wiki_provider)
      end

      def destroy
        # TODO: delete via service once data architecture (#72975) is complete
        flash[:notice] = I18n.t(:notice_successful_delete)
        redirect_to admin_settings_wiki_providers_path
      end

      def confirm_destroy
        # TODO: implement confirmation dialog
      end

      private

      def find_wiki_provider
        # TODO: load from database once data architecture (#72975) is complete
        @wiki_provider = Wikis::XWikiProvider.new(id: params[:id].to_i)
      end

      def wiki_provider_params
        params.expect(wikis_xwiki_provider: %i[name url])
      end
    end
  end
end
