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

module Documents
  class VersionsController < ApplicationController
    before_action :find_document
    before_action :authorize

    def index
      @max_version = @document.journals.maximum(:version).to_i
      journals_scope = @document.journals
        .preload(:user, :data)
        .order(version: :desc)

      page = [params[:page].to_i, 1].max
      per_page = page == 1 ? 20 : 50

      # For pages after the first, offset by 20 + (page - 2) * 50
      offset = page == 1 ? 0 : 20 + (page - 2) * 50
      @journals = journals_scope.offset(offset).limit(per_page + 1)

      @has_more = @journals.size > per_page
      @journals = @journals.first(per_page)
      @next_page = @has_more ? page + 1 : nil

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    private

    def find_document
      @document = Document.visible.find(params[:document_id])
      @project = @document.project
    end

    def default_breadcrumb
      @document.title
    end
  end
end
