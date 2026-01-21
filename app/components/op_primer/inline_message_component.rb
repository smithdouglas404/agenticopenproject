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

module OpPrimer
  # A simple component to render warning text.
  #
  # The warning text is rendered in the "attention" Primer color and
  # uses a leading alert Octicon for additional emphasis. This component
  # is designed to be used "inline", e.g. table cells, and in places
  # where a Banner component might be overkill.
  class InlineMessageComponent < Primer::Component # rubocop:disable OpenProject/AddPreviewForViewComponent
    SCHEME_ICON_MAPPINGS = {
      warning: :alert,
      critical: :alert,
      success: :"check-circle",
      unavailable: :alert
    }.freeze
    private_constant :SCHEME_ICON_MAPPINGS
    SCHEME_OPTIONS = SCHEME_ICON_MAPPINGS.keys

    SCHEME_SMALL_ICON_MAPPINGS = {
      warning: :"alert-fill",
      critical: :"alert-fill",
      success: :"check-circle-fill",
      unavailable: :"alert-fill"
    }.freeze
    private_constant :SCHEME_SMALL_ICON_MAPPINGS
    DEFAULT_SIZE = :medium
    SIZE_OPTIONS = [:small, DEFAULT_SIZE].freeze

    # @param scheme [Symbol] <%= one_of(SCHEME_OPTIONS) %>
    # @param size [Symbol] <%= one_of(SIZE_OPTIONS) %>
    # @param system_arguments [Hash] <%= link_to_system_arguments_docs %>
    def initialize(scheme:, size: DEFAULT_SIZE, **system_arguments) # rubocop:disable Lint/MissingSuper
      resolved_scheme = fetch_or_fallback(SCHEME_OPTIONS, scheme)
      resolved_size   = fetch_or_fallback(SIZE_OPTIONS, size, DEFAULT_SIZE)

      @system_arguments = system_arguments
      @system_arguments[:tag] ||= :div
      @system_arguments[:classes] = class_names(
        @system_arguments[:classes],
        "InlineMessage"
      )
      @system_arguments[:data] = merge_data(
        @system_arguments,
        { data: { size: resolved_size, variant: resolved_scheme } }
      )

      @icon_arguments = { classes: "InlineMessageIcon" }
      if resolved_size == :small
        @icon_arguments[:icon] = SCHEME_SMALL_ICON_MAPPINGS[resolved_scheme]
        @icon_arguments[:size] = :xsmall
      else
        @icon_arguments[:icon] = SCHEME_ICON_MAPPINGS[resolved_scheme]
      end
    end

    def render?
      content.present?
    end
  end
end
