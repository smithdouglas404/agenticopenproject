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
  class BacklogBucketHeaderComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers
    include OpTurbo::Streamable
    include Primer::FetchOrFallbackHelper
    include Redmine::I18n
    include Backlogs::CommonHelper

    attr_reader :backlog_bucket, :project, :work_packages, :collapsed, :current_user

    def initialize(
      backlog_bucket:,
      project:,
      work_packages:,
      folded: false,
      current_user: User.current
    )
      super()

      @backlog_bucket = backlog_bucket
      @project = project
      @work_packages = work_packages
      @collapsed = folded
      @current_user = current_user
    end

    def wrapper_uniq_by
      backlog_bucket.id
    end

    private

    def story_points
      @story_points ||= work_packages.sum { it.story_points || 0 }
    end

    def work_package_count
      @work_package_count ||= work_packages.size
    end
  end
end
