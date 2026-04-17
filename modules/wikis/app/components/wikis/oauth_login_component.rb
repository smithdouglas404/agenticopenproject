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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Wikis
  # Renders a "Connect account" button for a wiki provider that requires OAuth.
  # Can be included in any template — admin setup, work package tabs, etc.
  #
  # Usage:
  #   render(Wikis::OAuthLoginComponent.new(wiki_provider, destination_url: request.url))
  class OAuthLoginComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    alias_method :provider, :model

    def initialize(provider, destination_url: nil, **)
      @destination_url = destination_url
      super(provider, **)
    end

    def connect_url
      url_helpers.oauth_clients_ensure_connection_url(
        oauth_client_id: provider.oauth_client.client_id,
        storage_id: provider.id,
        destination_url: @destination_url
      )
    end
  end
end
