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
  # Conditionally renders a `Primer::Alpha::Layout` around the given content. If
  # the given condition is true, the component will render around the content.
  # If the condition is false, only the content is rendered.
  class ConditionalLayoutComponent < Primer::Component # rubocop:disable OpenProject/AddPreviewForViewComponent
    delegate :with_sidebar, to: :@layout

    # @param condition [Boolean] Whether or not to wrap the content in a Layout component.
    # @param layout_component_args [Hash] The arguments to pass to the Layout component.
    def initialize(condition:, **layout_component_args)
      super

      @condition = condition
      @layout = Primer::Alpha::Layout.new(**layout_component_args)
    end

    def call
      return content unless @condition

      render @layout
    end

    private

    def render?
      content?
    end

    def before_render
      content

      @layout.with_main { content }
    end
  end
end
