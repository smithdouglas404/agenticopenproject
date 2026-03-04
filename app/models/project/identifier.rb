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

class Project::Identifier < ApplicationRecord
  # Maximum length for project identifiers
  HANDLE_MAX_LENGTH = 100

  # reserved identifiers
  RESERVED_HANDLES = %w[new menu queries filters].freeze

  belongs_to :project, optional: false

  validates :handle,
            presence: true,
            uniqueness: true,
            length: { maximum: HANDLE_MAX_LENGTH },
            exclusion: RESERVED_HANDLES,
            if: ->(p) { p.persisted? || p.handle.present? }

  validates :handle,
            # Contains only a-z, 0-9, dashes and underscores but cannot consist of numbers only as it would clash with the id.
            format: { with: /\A(?!^\d+\z)[a-z0-9\-_]+\z/ },
            if: ->(p) { p.handle_changed? && p.handle.present? }

  validates :project_id,
            uniqueness: true,
            if: :current?

  scope :current, -> { where(current: true) }

  # TODO!!!! Just for testing journals!!
  before_validation :set_handle
  # acts_as_url :project_name,
  #             url_attribute: :handle,
  #             sync_url: false, # Don't update identifier when name changes
  #             only_when_blank: true, # Only generate when handle is not set
  #             limit: HANDLE_MAX_LENGTH,
  #             blacklist: RESERVED_HANDLES,
  #             adapter: OpenProject::ActsAsUrl::Adapter::OpActiveRecord # use a custom adapter able to handle edge cases

  def to_s
    handle
  end

  def set_handle # TODO!!!! Just for testing reasons!
    return if handle.present?
    binding.pry

    self.handle = rand(36**10).to_s(36)
    save!
  end
  def project_name
    project.name
  end
end
