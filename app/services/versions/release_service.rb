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
  # Releases a version of kind "release": handles its incomplete (open) work packages
  # according to the chosen strategy, then marks the release as closed (= released).
  #
  # Incomplete work packages are those linked to the release through its Release custom
  # field whose status is not closed. Strategies:
  #   * "roll_forward" - move them to another open release (+target_version+)
  #   * "decouple"     - clear the release link, returning them to the backlog
  #   * "force"        - leave them linked to the now-closed release
  class ReleaseService
    STRATEGIES = %w[roll_forward decouple force].freeze

    def initialize(user:, version:)
      @user = user
      @version = version
    end

    # @param strategy [String] one of STRATEGIES
    # @param target_version [Version, nil] required for "roll_forward"
    def call(strategy:, target_version: nil)
      strategy = strategy.to_s
      if (message = validation_error(strategy, target_version))
        return ServiceResult.failure(message:)
      end

      ApplicationRecord.transaction do
        apply_strategy(strategy, target_version)
        @version.update!(status: "closed")
      end

      ServiceResult.success(result: @version)
    rescue ActiveRecord::RecordInvalid => e
      ServiceResult.failure(message: e.message)
    end

    private

    def validation_error(strategy, target_version)
      return I18n.t("versions.release.errors.unauthorized") unless @user.allowed_in_project?(:manage_versions, @version.project)
      return I18n.t("versions.release.errors.not_a_release") unless @version.release?
      return I18n.t("versions.release.errors.already_released") unless @version.open?
      return I18n.t("versions.release.errors.invalid_strategy") unless STRATEGIES.include?(strategy)

      validate_target(target_version) if strategy == "roll_forward"
    end

    def validate_target(target_version)
      return I18n.t("versions.release.errors.target_required") if target_version.nil?

      unless target_version.is_a?(Version) && target_version.release? &&
             target_version.open? && target_version.id != @version.id
        I18n.t("versions.release.errors.invalid_target")
      end
    end

    def apply_strategy(strategy, target_version)
      return if strategy == "force"

      scope = incomplete_release_custom_values
      case strategy
      when "decouple"
        scope.delete_all
      when "roll_forward"
        # Avoid creating duplicate (work package, field, target) rows for work packages
        # already linked to the target release.
        already_in_target = CustomValue
          .where(custom_field_id: release_custom_field_ids, customized_type: "WorkPackage", value: target_version.id.to_s)
          .select(:customized_id)
        scope.where(customized_id: already_in_target).delete_all
        scope.update_all(value: target_version.id.to_s)
      end
    end

    # Custom values that link this release's incomplete work packages to it.
    def incomplete_release_custom_values
      incomplete_ids = @version.release_work_packages.merge(WorkPackage.with_status_open).select(:id)

      CustomValue.where(custom_field_id: release_custom_field_ids,
                        customized_type: "WorkPackage",
                        value: @version.id.to_s,
                        customized_id: incomplete_ids)
    end

    def release_custom_field_ids
      @release_custom_field_ids ||=
        WorkPackageCustomField.where(field_format: "version", version_kind: "release").select(:id)
    end
  end
end
