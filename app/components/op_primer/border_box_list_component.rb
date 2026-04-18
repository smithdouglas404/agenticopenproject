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
  # A BorderBox variant that exposes the underlying list element via
  # `list_arguments`, allowing callers to set attributes directly on the real
  # sortable container (`ul` by default) instead of only on the outer `.Box`.
  class BorderBoxListComponent < Primer::Component # :nodoc:
    DEFAULT_PADDING = :default
    PADDING_MAPPINGS = {
      DEFAULT_PADDING => "",
      :condensed => "Box--condensed",
      :spacious => "Box--spacious"
    }.freeze
    PADDING_SUGGESTION = "Perhaps you could consider using :padding options of #{PADDING_MAPPINGS.keys.to_sentence}?".freeze

    DEFAULT_ROW_SCHEME = :default
    ROW_SCHEME_MAPPINGS = {
      DEFAULT_ROW_SCHEME => "",
      :neutral => "Box-row--gray",
      :info => "Box-row--blue",
      :warning => "Box-row--yellow"
    }.freeze

    renders_one :header, "Primer::Beta::BorderBox::Header"

    renders_one :body, lambda { |**system_arguments|
      system_arguments[:tag] = :div
      system_arguments[:classes] = class_names(
        "Box-body",
        system_arguments[:classes]
      )

      Primer::BaseComponent.new(**system_arguments)
    }

    renders_one :footer, lambda { |**system_arguments|
      system_arguments[:tag] = :div
      system_arguments[:classes] = class_names(
        "Box-footer",
        system_arguments[:classes]
      )

      Primer::BaseComponent.new(**system_arguments)
    }

    renders_many :rows, lambda { |scheme: DEFAULT_ROW_SCHEME, **system_arguments|
      system_arguments[:tag] ||= :li
      system_arguments[:classes] = class_names(
        "Box-row",
        ROW_SCHEME_MAPPINGS[fetch_or_fallback(ROW_SCHEME_MAPPINGS.keys, scheme, DEFAULT_ROW_SCHEME)],
        system_arguments[:classes]
      )

      Primer::BaseComponent.new(**system_arguments)
    }

    def initialize(padding: DEFAULT_PADDING, list_arguments: {}, **system_arguments) # rubocop:disable Lint/MissingSuper
      @system_arguments = deny_tag_argument(**system_arguments)
      @system_arguments[:tag] = :div
      @system_arguments[:classes] = class_names(
        "Box",
        PADDING_MAPPINGS[fetch_or_fallback(PADDING_MAPPINGS.keys, padding, DEFAULT_PADDING)],
        system_arguments[:classes]
      )

      @system_arguments[:system_arguments_denylist] = { %i[p pt pb pr pl] => PADDING_SUGGESTION }
      @list_arguments = list_arguments
      @list_arguments[:tag] ||= :ul
    end

    def render?
      rows.any? || header.present? || body.present? || footer.present?
    end
  end
end
