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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Import
  # RSS memory growth profiling for import jobs.
  #
  # Enable by setting OPENPROJECT_JIRA_IMPORT_MEMORY_PROFILING=1 before starting the worker.
  # Output goes to log/jira_import_memory_profiling.log.
  module MemoryProfiling
    # Measures RSS and object allocation counts before/after the block.
    def with_memory_profile(phase)
      return yield unless memory_profiling_enabled?

      rss_before = process_rss_mb
      before     = GC.stat

      result = yield

      rss_after = process_rss_mb
      after     = GC.stat

      memory_logger.info(format_stats(phase, rss_before, rss_after, before, after))
      result
    end

    private

    def format_stats(phase, rss_before, rss_after, before, after)
      "#{phase.ljust(30)} " \
        "rss=#{rss_after.round(1)}MB rss_delta=#{(rss_after - rss_before).round(1)}MB " \
        "allocated_objects=#{after[:total_allocated_objects] - before[:total_allocated_objects]} " \
        "live_slots=#{after[:heap_live_slots]} " \
        "old_objects=#{after[:old_objects]} old_objects_delta=#{after[:old_objects] - before[:old_objects]} " \
        "heap_pages=#{after[:heap_allocated_pages]} heap_pages_delta=#{after[:heap_allocated_pages] - before[:heap_allocated_pages]} " \
        "major_gc=#{after[:major_gc_count] - before[:major_gc_count]} " \
        "minor_gc=#{after[:minor_gc_count] - before[:minor_gc_count]}"
    end

    def memory_profiling_enabled?
      ENV["OPENPROJECT_JIRA_IMPORT_MEMORY_PROFILING"].present?
    end

    def process_rss_mb
      if linux?
        File.read("/proc/self/status")[/VmRSS:\s+(\d+)/, 1].to_i / 1024.0
      else
        `ps -o rss= -p #{Process.pid}`.strip.to_i / 1024.0
      end
    end

    def linux?
      @linux ||= File.exist?("/proc/self/status")
    end

    def memory_logger
      @memory_logger ||= begin
        log_path = Rails.root.join("log/jira_import_memory_profiling.log")
        logger = ActiveSupport::Logger.new(log_path)
        logger.formatter = ->(_, datetime, _, msg) { "#{datetime.strftime('%Y-%m-%dT%H:%M:%S.%3N')} #{msg}\n" }
        logger
      end
    end
  end
end
