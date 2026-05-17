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

module Admin::Settings
  class ProjectReservedIdentifiersController < ::ApplicationController
    include OpTurbo::ComponentStream

    before_action :require_admin
    before_action :require_classic_mode
    before_action :find_slug, only: %i[confirm_dialog destroy]

    menu_item :project_reserved_identifiers_settings

    layout "admin"

    def index
      @groups = build_groups
      @total_count = @groups.sum { |g| g[:slugs].length }
    end

    def confirm_dialog
      respond_with_dialog Admin::Settings::ProjectReservedIdentifiers::ReleaseDialogComponent.new(slug: @slug)
    end

    def destroy
      @slug.destroy!
      redirect_to admin_settings_project_reserved_identifiers_path,
                  flash: { notice: t("admin.reserved_identifiers.released_notice", identifier: @slug.slug) }
    end

    private

    def find_slug
      @slug = Project.identifier_slugs.historically_reserved.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def build_groups
      reserved_slugs = classic_reserved_slugs
      projects_by_id = Project.where(id: reserved_slugs.pluck(:sluggable_id).uniq).index_by(&:id)

      reserved_slugs
        .group_by(&:sluggable_id)
        .filter_map { |pid, slugs| { project: projects_by_id[pid], slugs: } if projects_by_id[pid] }
        .sort_by { |g| g[:project].name.downcase }
    end

    def classic_reserved_slugs
      Project.identifier_slugs
             .historically_reserved
             .where("slug ~ ? AND slug !~ ?", "^[a-z0-9_-]+$", "^[0-9]+$")
             .order(created_at: :desc)
    end

    def require_classic_mode
      return unless Setting::WorkPackageIdentifier.semantic?

      redirect_to admin_settings_work_packages_identifier_path,
                  flash: { warning: t("admin.reserved_identifiers.not_available_in_semantic_mode") }
    end
  end
end
