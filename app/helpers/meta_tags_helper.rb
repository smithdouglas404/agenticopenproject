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

module MetaTagsHelper
  ##
  # Use meta-tags to output title and site name
  def output_title_and_meta_tags
    display_meta_tags title: page_title(*html_title_parts)
  end

  def page_title(*parts)
    (parts.reverse + [Setting.app_title]).join(" | ")
  end

  def initializer_meta_tag
    content = build_meta_content(
      locale: I18n.locale,
      default_locale: I18n.default_locale,
      instance_locale: Setting.default_language,
      first_week_of_year: locale_first_week_of_year,
      first_day_of_week: locale_first_day_of_week,
      environment: Rails.env,
      edition: OpenProject::Configuration.edition,
      asset_host: OpenProject::Configuration.rails_asset_host.presence
    )

    tag.meta(name: :openproject_initializer, content:)
  end

  def current_user_meta_tag(user)
    content = build_meta_content(user.slice(:id, :name).merge(logged_in: user.logged?))

    tag.meta(name: :current_user, content:)
  end

  def current_project_meta_tag(project)
    content = build_meta_content(project.slice(:id, :identifier, :name))

    tag.meta(name: :current_project, content:)
  end

  ##
  # Writer of html_title as string
  def html_title(*args)
    raise "Don't use html_title getter" if args.empty?

    @html_title ||= []
    @html_title += args
  end

  ##
  # The html title parts currently defined
  def html_title_parts
    [].tap do |parts|
      parts << h(@project.name) if @project
      parts.concat @html_title.map(&:to_s) if @html_title
    end
  end

  private

  def build_meta_content(content_values)
    content_values
      .filter_map { |key, value| "#{key.to_s.camelize(:lower)}=#{value}" unless value.nil? || value.try(:empty?) }
      .join(";")
  end
end
