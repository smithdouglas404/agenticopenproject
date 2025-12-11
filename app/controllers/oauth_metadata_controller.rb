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

class OAuthMetadataController < ApplicationController
  no_authorization_required! :protected_resource

  skip_before_action :check_if_login_required

  def protected_resource
    render json: {
      resource: resource_url,
      resource_name: Setting.app_title,
      authorization_servers:,
      scopes_supported: OpenProject::Authentication::Scope.values,
      bearer_methods_supported: ["header"],
      resource_documentation: OpenProject::Static::Links.url_for(:api_docs)
    }
  end

  private

  def authorization_servers
    OpenIDConnect::Provider.where(available: true).map(&:issuer) + [local_issuer]
  end

  def instance_base_url
    "http#{'s' if request.ssl?}://#{Setting.host_name}"
  end

  alias resource_url instance_base_url

  alias local_issuer instance_base_url
end
