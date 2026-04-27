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

module OpenProject
  module Common
    class WorkPackageCardBoxComponent < ApplicationComponent
      include Primer::AttributesHelper
      include OpPrimer::ComponentHelpers

      renders_one :header, ->(title:, count: nil) {
        Header.new(title:, count:, container:, list_id:, collapsed: folded?)
      }

      renders_one :empty_state, ->(title:, description: nil, icon: nil, **system_arguments) {
        system_arguments[:role] = "status"
        system_arguments[:aria] = merge_aria(
          system_arguments,
          aria: { live: "polite" }
        )

        blankslate = Primer::Beta::Blankslate.new(**system_arguments)
        blankslate.with_heading(tag: :h4).with_content(title)
        blankslate.with_description_content(description) if description
        blankslate.with_visual_icon(icon:) if icon
        blankslate
      }

      renders_one :footer

      attr_reader :work_packages, :project, :container, :current_user

      def initialize(work_packages:, project:, container:, current_user: User.current, **system_arguments)
        super()

        @work_packages = work_packages
        @project = project
        @container = container
        @current_user = current_user

        @system_arguments = system_arguments
        @system_arguments[:id] = container_id
        @system_arguments[:list_id] = list_id
        @system_arguments[:padding] = :condensed
        @system_arguments[:data] = merge_data(
          {
            data: {
              # Sprint historically used "container" alone. The shared box keeps the
              # first mirror container on the page for now until parent-specific DnD
              # handling is extracted in follow-up work.
              generic_drag_and_drop_target: "container mirrorContainer",
              target_container_accessor: ":scope > ul",
              target_id: drop_target_id,
              target_allowed_drag_type: "story"
            }
          },
          @system_arguments
        )
      end

      def before_render
        raise ArgumentError, "empty_state slot is required" unless empty_state?
      end

      def cards
        @cards ||= work_packages.map do |work_package|
          WorkPackageCardComponent.new(work_package:, project:, container:, current_user:)
        end
      end

      private

      def folded?
        current_user.pref[:backlogs_versions_default_fold_state] == "closed"
      end

      def container_id
        case container
        when Sprint, BacklogBucket
          dom_id(container)
        else
          "inbox_#{project.id}"
        end
      end

      def list_id
        "#{container_id}-list"
      end

      def drop_target_id
        case container
        when Sprint then "sprint:#{container.id}"
        when BacklogBucket then "backlog_bucket:#{container.id}"
        else "inbox"
        end
      end
    end
  end
end
