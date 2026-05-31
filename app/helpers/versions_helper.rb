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

module VersionsHelper
  # Returns a set of options for a select field, grouped by project.
  def version_options_for_select(versions, selected = nil)
    grouped = versions_by_project((versions + [selected]).compact)

    if grouped.size > 1
      grouped_options_for_select(grouped, selected&.id)
    else
      options_for_select(grouped.values.first || [], selected&.id)
    end
  end

  def link_to_version(version, html_options = {}, options = {})
    return "" unless version.is_a?(Version)

    html_options = html_options.merge(id: link_to_version_id(version))

    link_name = options[:before_text].to_s.html_safe + format_version_name(version, options[:project] || @project)
    link_to_if version.visible?,
               link_name,
               { controller: "/versions", action: "show", id: version },
               html_options
  end

  def version_dates(version)
    formatted_dates =
      %i[start_date due_date]
        .filter { |attr| version.send(attr) }
        .map { |attr| "#{Version.human_attribute_name(attr)} #{format_date(version.send(attr))}" }
    safe_join(formatted_dates, "<br>".html_safe)
  end

  def link_to_version_id(version)
    ERB::Util.url_encode("version-#{version.name}")
  end

  def format_version_name(version, project = @project)
    h(version.to_s_for_project(project))
  end

  def format_version_sharing(sharing)
    sharing = "none" unless Version::VERSION_SHARINGS.include?(sharing)
    I18n.t("label_version_sharing_#{sharing}")
  end

  def versions_by_project(versions)
    versions.uniq.inject(Hash.new { |h, k| h[k] = [] }) do |hash, version|
      hash[version.project.name] << [version.name, version.id]
      hash
    end
  end

  # The project settings screen that manages a version, depending on its kind.
  # Releases are managed on the Releases screen, everything else on the Versions screen.
  def version_settings_path(version)
    if version.release?
      project_settings_releases_path(version.project)
    else
      project_settings_versions_path(version.project)
    end
  end

  # Localized "Version"/"Release" label for a version depending on its kind.
  # +suffix+ is one of :plural, :new, :edit.
  def version_kind_label(version, suffix)
    key = version.release? ? "release" : "version"
    t(:"label_#{key}_#{suffix}")
  end

  # Link to the work package view filtered by the Release custom field for this
  # version, so users can see/work with the full list. Returns nil when no release
  # custom field exists.
  def release_work_packages_path(version)
    release_cf_ids = WorkPackageCustomField.where(field_format: "version", version_kind: "release").pluck(:id)
    return if release_cf_ids.empty?

    # Mirror Version#release_work_packages, which matches work packages by the Release
    # custom field value regardless of project (so shared/system releases include work
    # packages from other projects). Hence link to the cross-project work package view
    # filtered by the Release custom field, NOT the release project's scoped view (which
    # would omit work packages from the other projects the hub counts/lists).
    #
    # Work package query filters are AND-combined, so several release custom fields
    # cannot be OR-ed into one link; with the expected single Release field this exactly
    # mirrors the hub's relation.
    work_packages_path(
      query_props: { f: [{ n: "customField#{release_cf_ids.first}", o: "=", v: [version.id.to_s] }] }.to_json
    )
  end

  def version_wp_overview_graph_initial_filters(version)
    filters = []
    case version.sharing
    when "hierarchy", "tree"
      filters << { project: { operator: "=", values: version.projects.visible.ids } }
    when "descendants"
      filters << { subprojectId: { operator: "*", values: [] } }
    end
    filters << { version: { operator: "=", values: [version.id] } }

    filters # return as an array, not JSON string
  end
end
