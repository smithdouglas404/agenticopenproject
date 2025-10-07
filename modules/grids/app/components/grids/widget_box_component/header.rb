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

module Grids
  class WidgetBoxComponent < ApplicationComponent
    class Header < ApplicationComponent
      attr_reader :id, :title

      # @param system_arguments [Hash] <%= link_to_system_arguments_docs %>
      def initialize(title:, **system_arguments)
        super()
        @title = title
        @system_arguments = system_arguments
        @system_arguments[:tag] = :header
        @system_arguments[:id] ||= self.class.generate_id
        @system_arguments[:test_selector] = "op-widget-box--header"
        @system_arguments[:classes] = class_names(
          @system_arguments[:classes],
          "op-widget-box--header"
        )
        @id = @system_arguments[:id]
      end

      def render?
        title.present?
      end
    end
  end
end
