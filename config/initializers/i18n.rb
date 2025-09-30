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

# load custom translation rules, as stored in config/locales/plurals.rb
# to be aware of e.g. Japanese not having a plural from for nouns
require "open_project/translations/pluralization_backend"
I18n::Backend::Simple.include OpenProject::Translations::PluralizationBackend

# Adds fallback to default locale for untranslated strings
I18n::Backend::Simple.include I18n::Backend::Fallbacks

Rails.application.reloader.to_prepare do
  # As we enabled +config.i18n.fallbacks+, Rails will fall back
  # to the default locale.
  # When other locales are available, fall back to them.
  if Setting.table_exists? # don't want to prevent migrations
    defaults = Set.new(I18n.fallbacks.defaults + Redmine::I18n.valid_languages.map(&:to_sym))
    I18n.fallbacks.defaults = defaults
  end
end
