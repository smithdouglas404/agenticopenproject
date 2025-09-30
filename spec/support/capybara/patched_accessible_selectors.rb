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

#  Modifies combo_box_list_box provided by Capybara Accessible Selectors
#  to work with our autocompleter (ng-select) implementation: we allow
# `aria-owns`/`aria-controls` to be specified on ancestor of the
# `listbox`.
Capybara.modify_selector(:combo_box_list_box) do
  xpath do |input|
    ids = (input[:"aria-owns"] || input[:"aria-controls"])&.split(/\s+/)&.compact
    raise Capybara::ElementNotFound, "listbox cannot be found without attributes aria-owns or aria-controls" if ids.blank?

    XPath.anywhere[[
      XPath.descendant[XPath.attr(:role) == "listbox"],
      ids.map { |id| XPath.attr(:id) == id }.reduce(:|)
    ].reduce(:&)]
  end
end
