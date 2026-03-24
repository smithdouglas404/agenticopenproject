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

# Permanent record of every (project, sequence_number) assignment for work packages.
#
# When a work package is created, a row is inserted here to reserve the sequence number.
# When a work package moves to another project, the old row stays (permanently reserving
# that sequence number in the source project) and a new row is created for the target project.
#
# The optional FK to friendly_id_slugs links historical slug strings back to their
# structured roots (project, work_package, sequence_number) for auditability.
class HistoricalWorkPackageIdentifier < ApplicationRecord
  belongs_to :project
  belongs_to :work_package
  belongs_to :friendly_id_slug, class_name: "FriendlyId::Slug", optional: true

  validates :sequence_number, presence: true,
                              numericality: { only_integer: true, greater_than: 0 },
                              uniqueness: { scope: :project_id }
end
