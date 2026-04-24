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

class PersistedView < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :principal, optional: true, inverse_of: :persisted_views
  belongs_to :query, polymorphic: true, optional: true

  belongs_to :parent, class_name: "PersistedView", optional: true
  has_many :children, class_name: "PersistedView", foreign_key: "parent_id", dependent: :destroy, inverse_of: :parent

  acts_as_favoritable

  enum :category, {
    work_package: "work_package",
    project: "project",
    resource_management: "resource_management"
  }, validate: { allow_nil: true }

  validates :name, presence: true, length: { maximum: 255 }

  scope :public_views, -> { where(public: true) }
  scope :private_views, ->(principal: User.current) { where(public: false, principal:) }

  scope :visible, (lambda do |principal: User.current|
    public_views.or(private_views(principal:))
  end)

  after_destroy :destroy_query_if_orphaned

  # Returns the query of this view or, if not set, the query of the parent view.
  def effective_query
    query || parent&.effective_query
  end

  private

  # When this view is destroyed, also destroy its query unless another public
  # view still references it. Views belonging to the same owner that are also
  # going away (e.g. during user deletion) do not count as "still referencing"
  # since only public views keep a query alive.
  def destroy_query_if_orphaned
    return if query.nil?
    return if PersistedView.exists?(query:, public: true)

    query.destroy!
  end
end
