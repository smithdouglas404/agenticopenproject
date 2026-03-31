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

# Prevent load-order problems in case openproject-plugins is listed after a plugin in the Gemfile
# or not at all
require "open_project/plugins"

module OpenProject::Wikis
  class Engine < ::Rails::Engine
    engine_name :openproject_wikis

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-wikis",
             author_url: "https://openproject.org" do
               menu :work_package_split_view,
                    :wikis,
                    { tab: :wikis },
                    skip_permissions_check: true,
                    after: :relations,
                    if: ->(_project) {
                      Wikis::Provider.enabled.exists? &&
                        OpenProject::FeatureDecisions.wiki_enhancements_active?
                    }
             end

    initializer "openproject_wikis.inflections" do
      ActiveSupport::Inflector.inflections(:en) do |inflect|
        inflect.acronym "XWiki"
      end

      OpenProject::Inflector.rule do |basename, abspath|
        case basename
        when "xwiki"
          "XWiki"
        when /\Axwiki_(.*)\z/
          "XWiki#{default_inflect($1, abspath)}"
        end
      end
    end

    config.to_prepare do
      API::V3::Configuration::ConfigurationRepresenter.property(
        :wikisAvailable,
        getter: ->(*) { ::Wikis::Provider.enabled.exists? }
      )
    end

    replace_principal_references "Wikis::PageLink" => %i[author_id]
  end
end
