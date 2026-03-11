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

class OpenProject::JournalFormatter::AssociatedVersion < JournalFormatter::Base
  def render(key, values, options = { html: true })
    label, old_value, value = format_details(key, values)

    if options[:html]
      label, old_value, value = *format_html_details(label, old_value, value)
    end

    render_detail_text(label, value, old_value)
  end

  private

  def render_detail_text(label, value, old_value)
    if value.blank?
      I18n.t(:text_journal_deleted, label:, old: old_value)
    else
      I18n.t(:text_journal_added, label:, value:)
    end
  end

  def label(key)
    kind_attr = key.start_with?("observed_in_") ? :observed_in_versions : :target_versions
    WorkPackage.human_attribute_name(kind_attr)
  end
end
