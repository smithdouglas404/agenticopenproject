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

class BackgroundTask < ApplicationRecord
  # Task types
  SEMANTIC_ID_CONVERSION = "semantic_id_conversion"
  SEMANTIC_ID_REVERSION  = "semantic_id_reversion"

  # Statuses
  PENDING    = "pending"
  PROCESSING = "processing"
  COMPLETE   = "complete"
  FAILED     = "failed"

  validates :task_type, presence: true
  validates :status, inclusion: { in: [PENDING, PROCESSING, COMPLETE, FAILED] }

  scope :pending,     -> { where(status: PENDING) }
  scope :processing,  -> { where(status: PROCESSING) }
  scope :in_progress, -> { where(status: [PENDING, PROCESSING]) }

  def start!
    update!(status: PROCESSING, started_at: Time.current)
  end

  def complete!(metadata = {})
    update!(status: COMPLETE, completed_at: Time.current, metadata:)
  end

  def fail!(metadata = {})
    update!(status: FAILED, failed_at: Time.current, metadata:)
  end
end
