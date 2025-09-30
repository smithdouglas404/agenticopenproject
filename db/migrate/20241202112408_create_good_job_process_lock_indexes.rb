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

class CreateGoodJobProcessLockIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  # rubocop:disable Metrics/AbcSize
  def change
    reversible do |dir|
      dir.up do
        unless connection.index_name_exists?(:good_jobs, :index_good_jobs_on_priority_scheduled_at_unfinished_unlocked)
          add_index :good_jobs, %i[priority scheduled_at],
                    order: { priority: "ASC NULLS LAST", scheduled_at: :asc },
                    where: "finished_at IS NULL AND locked_by_id IS NULL",
                    name: :index_good_jobs_on_priority_scheduled_at_unfinished_unlocked,
                    algorithm: :concurrently
        end

        unless connection.index_name_exists?(:good_jobs, :index_good_jobs_on_locked_by_id)
          add_index :good_jobs, :locked_by_id,
                    where: "locked_by_id IS NOT NULL",
                    name: :index_good_jobs_on_locked_by_id,
                    algorithm: :concurrently
        end

        unless connection.index_name_exists?(:good_job_executions, :index_good_job_executions_on_process_id_and_created_at)
          add_index :good_job_executions, %i[process_id created_at],
                    name: :index_good_job_executions_on_process_id_and_created_at,
                    algorithm: :concurrently
        end
      end

      dir.down do
        if connection.index_name_exists?(
          :good_jobs, :index_good_jobs_on_priority_scheduled_at_unfinished_unlocked
        )
          remove_index(:good_jobs, name: :index_good_jobs_on_priority_scheduled_at_unfinished_unlocked)
        end

        if connection.index_name_exists?(:good_jobs, :index_good_jobs_on_locked_by_id)
          remove_index(:good_jobs, name: :index_good_jobs_on_locked_by_id)
        end

        if connection.index_name_exists?(
          :good_job_executions, :index_good_job_executions_on_process_id_and_created_at
        )
          remove_index(:good_job_executions, name: :index_good_job_executions_on_process_id_and_created_at)
        end
      end
    end
  end
  # rubocop:enable Metrics/AbcSize
end
