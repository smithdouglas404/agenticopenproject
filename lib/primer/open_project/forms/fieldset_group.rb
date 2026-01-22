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
        ##
        # @param title [String] The title displayed as the heading for the fieldset
        # @param inputs [Array<Primer::Forms::Dsl::Input>] Array of form inputs to be grouped
        # @param builder [ActionView::Helpers::FormBuilder] The form builder instance
        # @param form [Primer::Forms::BaseForm] The form object
        # @param layout [Symbol] Layout style for the input group (default: :default_layout)
        # @param heading_arguments [Hash] Arguments passed to the heading component
        # @option heading_arguments [String] :id The ID for the heading element
        # @option heading_arguments [Symbol] :tag The HTML tag for the heading (default: :h3)
        # @option heading_arguments [Symbol] :size The size of the heading (default: :medium)
        # @param group_arguments [Hash] Arguments passed to the input group component
        # @param system_arguments [Hash] Additional system arguments passed to the section wrapper
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
          @system_arguments[:mb] ||= 4
          @system_arguments[:aria] ||= {}
          @system_arguments[:aria][:labelledby] = @heading_arguments[:id]
          @system_arguments[:hidden] = :none if inputs.all?(&:hidden?)
        end
      end
    end
  end
end
