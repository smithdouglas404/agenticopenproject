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

module Backlogs
  class ListBoxComponent < ApplicationComponent
    include Primer::AttributesHelper

    PADDING_MAPPINGS = {
      default: nil,
      condensed: "Box--condensed",
      spacious: "Box--spacious"
    }.freeze

    ROW_SCHEME_MAPPINGS = {
      default: nil,
      neutral: "Box-row--gray",
      info: "Box-row--blue",
      warning: "Box-row--yellow"
    }.freeze

    renders_one :header, lambda { |**system_arguments|
      system_arguments[:tag] = :div
      system_arguments[:classes] = class_names("Box-header", system_arguments[:classes])

      Primer::BaseComponent.new(**system_arguments)
    }

    renders_many :rows, lambda { |scheme: :default, **system_arguments|
      system_arguments[:tag] ||= :li
      system_arguments[:classes] = class_names(
        "Box-row",
        ROW_SCHEME_MAPPINGS.fetch(scheme, ROW_SCHEME_MAPPINGS[:default]),
        system_arguments[:classes]
      )

      Primer::BaseComponent.new(**system_arguments)
    }

    def initialize(padding: :default, list_arguments: {}, **system_arguments)
      super()

      @system_arguments = system_arguments
      @system_arguments[:tag] = :div
      @system_arguments[:classes] = class_names(
        "Box",
        PADDING_MAPPINGS.fetch(padding, PADDING_MAPPINGS[:default]),
        system_arguments[:classes]
      )

      @list_arguments = list_arguments
      @list_arguments[:tag] ||= :ul
    end
  end
end
