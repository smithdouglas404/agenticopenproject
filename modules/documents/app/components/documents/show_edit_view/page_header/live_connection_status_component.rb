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
#

module Documents
  module ShowEditView
    module PageHeader
      # Displays an offline status indicator in the document page header.
      # Hidden by default and toggled by the documents--connection-status
      # Stimulus controller, which listens for connection state changes
      # dispatched by the BlockNote React editor.
      class LiveConnectionStatusComponent < ApplicationComponent
        include OpPrimer::ComponentHelpers
        include OpTurbo::Streamable

        def call
          # The `indicator` target is referenced by the Stimulus controller
          # to show/hide this component when the connection state changes
          component_wrapper(
            tag: :span,
            display: :none,
            data: { "documents--connection-status-target": "indicator" }
          ) do
            flex_layout(align_items: :center) do |flex|
              flex.with_column(mr: 1) do
                render(Primer::Beta::Octicon.new(icon: :"cloud-offline", color: :subtle))
              end
              flex.with_column do
                render(Primer::Beta::Text.new(color: :subtle)) do
                  I18n.t("documents.show_edit_view.connection_status.offline")
                end
              end
            end
          end
        end
      end
    end
  end
end