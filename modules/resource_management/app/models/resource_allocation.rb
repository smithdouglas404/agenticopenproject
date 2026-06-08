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

class ResourceAllocation < ApplicationRecord
  ALLOWED_ENTITY_TYPES = %w[WorkPackage].freeze

  belongs_to :entity, polymorphic: true, optional: false
  belongs_to :principal, class_name: "User", optional: true, inverse_of: :resource_allocations
  belongs_to :requested_by, class_name: "User", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  serialize :user_filter, coder: Queries::Serialization::Filters.new(UserQuery)

  acts_as_journalized

  register_journal_formatted_fields "state", formatter_key: :plaintext
  register_journal_formatted_fields "start_date", "end_date", formatter_key: :datetime
  register_journal_formatted_fields "allocated_time", formatter_key: :allocated_time
  register_journal_formatted_fields "principal_id", "requested_by_id", "reviewed_by_id",
                                    formatter_key: :named_association
  register_journal_formatted_fields "entity_gid", formatter_key: :polymorphic_association
  register_journal_formatted_fields "filter_name", formatter_key: :plaintext

  enum :state, {
    requested: "requested",
    allocated: "allocated",
    rejected: "rejected",
    canceled: "canceled"
  }

  scope :needs_principal_assignment, -> { where(principal_explicit: false, principal_id: nil) }

  # The `allocated` allocations for the given work packages, grouped by work
  # package id and with principals eager-loaded. Loaded once per page so the
  # allocation columns (progress bar and members) share a single query.
  def self.allocated_for_work_packages(work_packages)
    allocated
      .where(entity_type: "WorkPackage", entity_id: work_packages.map(&:id))
      .includes(:principal)
      .order(:id)
      .group_by(&:entity_id)
  end

  # The subset of the given allocations' principal ids that `user` may see.
  # Used to anonymise members the current user is not allowed to know about.
  def self.visible_principal_ids(allocations, user)
    principal_ids = allocations.filter_map(&:principal_id).uniq
    return Set.new if principal_ids.empty?

    Principal.visible(user).where(id: principal_ids).pluck(:id).to_set
  end

  validates :state, :start_date, :end_date, presence: true
  validates :allocated_time,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  validates :entity_type,
            inclusion: { in: ALLOWED_ENTITY_TYPES },
            allow_blank: true

  with_options if: :principal_explicit? do
    validates :principal, presence: true
    validates :filter_name, absence: true
    validates :user_filter, absence: true
  end

  validates :filter_name, presence: true, unless: :principal_explicit?

  validate :end_date_after_start_date

  # Resource allocations are scoped to whatever project their (polymorphic)
  # entity belongs to. Authorization in the contracts hangs off this.
  def project
    entity&.project
  end

  def entity_gid
    entity&.to_gid.to_s
  end

  def entity=(value)
    if value.is_a?(String) && value.starts_with?("gid://")
      super(GlobalID::Locator.locate(value, only: ALLOWED_ENTITY_TYPES.map(&:safe_constantize)))
    else
      super
    end
  end

  def filter_based?
    !principal_explicit?
  end

  def user_assigned?
    principal_id.present?
  end

  def needs_principal_assignment?
    !principal_explicit? && principal_id.blank?
  end

  def candidate_query
    UserQuery.new.tap do |query|
      user_filter.each do |filter|
        query.where(filter.field, filter.operator, filter.values)
      end
    end
  end

  def allocated_hours
    return if allocated_time.nil?

    allocated_time / 60.0
  end

  def allocated_hours=(value)
    hours = value.is_a?(String) ? DurationConverter.parse(value) : value
    self.allocated_time = hours.nil? ? nil : (Float(hours) * 60).round
  rescue ChronicDuration::DurationParseError, ArgumentError, TypeError
    self.allocated_time = nil
  end

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date > start_date

    errors.add :end_date, :greater_than_start_date
  end
end
