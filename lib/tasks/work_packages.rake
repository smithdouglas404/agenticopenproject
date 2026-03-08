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

require "json"
require "time"

namespace :openproject do
  namespace :work_packages do
    desc "Backfill work_packages.updated_at from a JSON mapping keyed by work package number"
    task backfill_updated_at: [:environment] do
      mapping_path = ENV.fetch("MAPPING_PATH", nil)
      batch_size = [ENV.fetch("BATCH_SIZE", "1000").to_i, 1].max
      dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", nil))

      if mapping_path.blank?
        abort <<~USAGE

          Missing MAPPING_PATH.
          Usage:
            bundle exec rake openproject:work_packages:backfill_updated_at \
              MAPPING_PATH=/absolute/path/to/work-package-updated-at.json \
              [DRY_RUN=true] \
              [BATCH_SIZE=1000]

        USAGE
      end

      unless File.file?(mapping_path)
        abort "Mapping file not found: #{mapping_path}"
      end

      raw_mapping = JSON.parse(File.read(mapping_path))
      unless raw_mapping.is_a?(Hash)
        abort "Expected a JSON object mapping work package numbers to timestamps."
      end

      updates = {}
      invalid_entries = []

      raw_mapping.each do |raw_id, raw_timestamp|
        work_package_id = Integer(raw_id, 10)
        timestamp = Time.iso8601(raw_timestamp.to_s).utc
        updates[work_package_id] = timestamp
      rescue ArgumentError, TypeError
        invalid_entries << [raw_id, raw_timestamp]
      end

      if updates.empty?
        abort "No valid rows found in #{mapping_path}."
      end

      existing_ids = WorkPackage.where(id: updates.keys).pluck(:id)
      missing_count = updates.size - existing_ids.size

      puts "Loaded #{updates.size} valid update rows from #{mapping_path}."
      puts "Found #{existing_ids.size} matching work packages in the database."
      puts "Skipped #{missing_count} rows because work package IDs do not exist." if missing_count.positive?
      puts "Skipped #{invalid_entries.size} invalid rows." if invalid_entries.any?

      if dry_run
        puts "DRY_RUN enabled. No database changes were written."
        next
      end

      connection = ActiveRecord::Base.connection
      updated_rows = 0

      existing_ids.each_slice(batch_size) do |ids|
        values_sql = ids
                       .map { |id| "(#{id}, #{connection.quote(updates.fetch(id).iso8601(6))}::timestamptz)" }
                       .join(", ")

        next if values_sql.blank?

        sql = <<~SQL.squish
          UPDATE work_packages AS wp
          SET updated_at = source.updated_at
          FROM (VALUES #{values_sql}) AS source(id, updated_at)
          WHERE wp.id = source.id
            AND wp.updated_at IS DISTINCT FROM source.updated_at
        SQL

        updated_rows += connection.update(sql)
      end

      unchanged_rows = existing_ids.size - updated_rows

      puts "Backfill complete."
      puts "Updated rows: #{updated_rows}"
      puts "Unchanged rows: #{unchanged_rows}"
    end
  end
end
