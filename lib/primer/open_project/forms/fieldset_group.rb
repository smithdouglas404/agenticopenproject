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

module Primer
  module OpenProject
    module Forms
      # :nodoc:
      class FieldsetGroup < Primer::Forms::BaseComponent
        def initialize( # rubocop:disable Metrics/AbcSize
          title:,
          inputs:,
          builder:,
          form:,
          layout: Primer::Forms::Group::DEFAULT_LAYOUT,
          heading_arguments: {},
          group_arguments: {},
          **system_arguments
        )
          super()

          @title = title

          @heading_arguments = heading_arguments
          @heading_arguments[:id] ||= "subhead-#{SecureRandom.uuid}"
          @heading_arguments[:tag] ||= :h3
          @heading_arguments[:size] ||= :medium

          @fieldset_arguments = {
            legend_text: @title,
            visually_hide_legend: true,
            aria: { labelledby: @heading_arguments[:id] }
          }
          @group_arguments = group_arguments.merge(inputs:, builder:, form:, layout:)

          @system_arguments = system_arguments
          @system_arguments[:tag] = :section
          @system_arguments[:aria] ||= {}
          @system_arguments[:aria][:labelledby] = @heading_arguments[:id]
          @system_arguments[:hidden] = :none if inputs.all?(&:hidden?)
        end
      end
    end
  end
end
