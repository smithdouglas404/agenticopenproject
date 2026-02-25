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

module Import
  class JiraImportJournals
    attr_reader :work_package

    def initialize(work_package:)
      @work_package = work_package
      @pending_entries = []
    end

    def update_creation_entry(date_time:)
      creation_journal = work_package.journals.reload.first
      return unless creation_journal

      parsed = Time.zone.parse(date_time.to_s)
      creation_journal.update_columns(
        created_at: parsed,
        updated_at: parsed,
        validity_period: (parsed..)
      )
    end

    def add_history(history:)
      group_history_entries(history).each do |group|
        @pending_entries << { type: :history, data: group, created: group["created"] }
      end
    end

    def add_comment(comment:, user:)
      @pending_entries << { type: :comment, data: comment, user:, created: comment["created"] }
    end

    def call
      @pending_entries.sort_by { |e| e[:created] }.each do |entry|
        case entry[:type]
        when :history then create_history_journal(entry[:data])
        when :comment then create_comment_journal(entry[:data], entry[:user])
        end
      end
    end

    private

    def same_minute?(a, b)
      Time.zone.parse(a.to_s).change(sec: 0) == Time.zone.parse(b.to_s).change(sec: 0)
    end

    def group_history_entries(history)
      groups = []
      current = nil

      history.each do |entry|
        author_name = entry.dig("author", "displayName")
        created = entry["created"]
        items = entry["items"] || []
        has_description = items.any? { |item| item["field"]&.downcase == "description" }

        if current &&
           same_minute?(current["created"], created) &&
           current["author"]["displayName"] == author_name &&
           !(current[:has_description] && has_description)
          current["items"].concat(items)
          current[:has_description] ||= has_description
        else
          groups << current if current
          current = { "created" => created, "author" => { "displayName" => author_name },
                      "items" => items.dup, has_description: }
        end
      end
      groups << current if current
      groups
    end

    def create_history_journal(entry)
      author_name = entry.dig("author", "displayName")
      items = convert_history_items(entry["items"])
      date_time = Time.zone.parse(entry["created"].to_s)

      work_package.update_column(:updated_at, date_time)

      cause = Journal::CausedByImport.new(author_name:, history: items)
      work_package.add_journal(user: User.system, notes: "", cause:)
      work_package.save_journals
    end

    def create_comment_journal(comment, user)
      notes = convert_rich_text(comment["body"])
      date_time = Time.zone.parse(comment["created"].to_s)

      work_package.update_column(:updated_at, date_time)
      work_package.add_journal(user:, notes:, internal: false)
      work_package.save_journals
    end

    def convert_history_items(items)
      return [] if items.blank?

      items.map do |item|
        if item["field"]&.downcase == "description"
          item.merge(
            "fromString" => convert_rich_text(item["fromString"]),
            "toString" => convert_rich_text(item["toString"])
          )
        else
          item
        end
      end
    end

    def convert_rich_text(description)
      return "" if description.blank?

      Import::JiraWikiMarkupConverter.new(description).convert
    end
  end
end
