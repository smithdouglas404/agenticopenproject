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

module Versions
  # Runs Versions::ReleaseService in the background, used for releases with many
  # incomplete work packages so the web request is not blocked. Parameters are
  # validated synchronously before this job is enqueued.
  class ReleaseJob < ApplicationJob
    queue_with_priority :default

    def perform(version_id:, user_id:, strategy:, target_version_id: nil)
      version = Version.find_by(id: version_id)
      user = User.find_by(id: user_id)
      return if version.nil? || user.nil?

      target_version = (Version.find_by(id: target_version_id) if target_version_id.present?)

      result = Versions::ReleaseService
        .new(user:, version:)
        .call(strategy:, target_version:)

      # Parameters were validated before enqueuing, but state can change before the job
      # runs (e.g. the target release was closed). Log such failures so they are not
      # silently lost; unexpected errors still propagate and fail the job normally.
      unless result.success?
        Rails.logger.error(
          "Versions::ReleaseJob: releasing version #{version_id} (strategy=#{strategy}) failed: #{result.message}"
        )
      end

      result
    end
  end
end
