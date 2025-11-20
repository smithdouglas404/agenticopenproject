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

module Projects
  module Wizard
    class FooterComponent < ApplicationComponent
      include OpPrimer::ComponentHelpers

      def initialize(project:, custom_fields_by_section:, current_section:)
        super

        @project = project
        @custom_fields_by_section = custom_fields_by_section
        @current_section = current_section
      end

      private

      attr_reader :project, :custom_fields_by_section, :current_section

      def sections
        @sections ||= custom_fields_by_section.keys
      end

      def current_section_index
        @current_section_index ||= sections.index(current_section) || 0
      end

      def total_sections
        sections.count
      end

      def progress_percentage
        return 0 if total_sections.zero?

        ((current_section_index + 1).to_f / total_sections * 100).round
      end

      def previous_section
        return nil if current_section_index.zero?

        sections[current_section_index - 1]
      end

      def next_section
        return nil if current_section_index >= sections.count - 1

        sections[current_section_index + 1]
      end

      def first_section?
        current_section_index.zero?
      end

      def last_section?
        current_section_index >= sections.count - 1
      end
    end
  end
end
