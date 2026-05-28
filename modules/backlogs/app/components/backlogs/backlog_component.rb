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
  class BacklogComponent < ApplicationComponent
    include Primer::AttributesHelper
    include OpTurbo::Streamable
    include CommonHelper

    attr_reader :work_packages_by_backlog_id, :buckets, :project, :current_user

    def initialize(buckets:,
                   work_packages_by_backlog_id:,
                   project:,
                   current_user: User.current)
      super()

      @work_packages_by_backlog_id = work_packages_by_backlog_id
      @buckets = buckets
      @project = project
      @current_user = current_user
    end

    def wrapper_uniq_by
      project
    end

    private

    def total
      @total ||= work_packages_by_backlog_id.values.sum(&:count)
    end

    def initially_rendered_buckets
      work_packages_available = 100 - work_packages_by_backlog_id[buckets.first.id]&.size.to_i

      rendered_buckets = [buckets.first]

      buckets[1..].each do |bucket|
        if work_packages_by_backlog_id[bucket.id].nil?
          work_packages_available -= 1

          rendered_buckets << bucket
        elsif work_packages_by_backlog_id[bucket.id].size < work_packages_available
          work_packages_available -= work_packages_by_backlog_id[bucket.id].size

          rendered_buckets << bucket
        else
          break
        end
      end

      rendered_buckets
    end

    def turbo_frame_only_buckets
      buckets - initially_rendered_buckets
    end

    def bucket_skeleton_height(bucket)
      54 + (40 * work_packages_by_backlog_id[bucket.id]&.size.to_i) + (work_packages_by_backlog_id[bucket.id].nil? ? 80 : 0)
    end
  end
end
