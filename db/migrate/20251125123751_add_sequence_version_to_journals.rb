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

class AddSequenceVersionToJournals < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_column :journals, :sequence_version, :integer

    add_index :journals,
              %i[journable_type journable_id sequence_version],
              algorithm: :concurrently,
              name: "index_journals_on_journable_and_sequence_version"

    begin
      say_with_time "Backfilling sequence_version for wp_journals" do
        backfill_sequence_versions
      end

      if Journal.where(journable_type: "WorkPackage", sequence_version: nil).exists?
        raise "Backfill incomplete: NULL sequence_version still exists"
      end

      create_trigger_and_function

    rescue => e
      warn "Sequence_version migration failed: #{e}"
      cleanup_failed_migration
      raise e
    end
  end

  def down
    cleanup_failed_migration
  end

  private

  def backfill_sequence_versions
    Journal
      .where(journable_type: "WorkPackage")
      .distinct
      .pluck(:journable_id)
      .each_slice(1000) do |wp_ids|

      wp_ids.each do |wp_id|
        Journal.connection.execute(<<~SQL)
        UPDATE journals j
        SET sequence_version = ranked.seq
        FROM (
          SELECT id, ROW_NUMBER() OVER (ORDER BY version ASC) AS seq
          FROM journals
          WHERE journable_id = #{wp_id}
            AND journable_type = 'WorkPackage'
        ) AS ranked
        WHERE j.id = ranked.id
      SQL
      end
    end
  end

  def create_trigger_and_function
    execute <<~SQL
      CREATE OR REPLACE FUNCTION set_journal_sequence_version()
      RETURNS trigger AS $$
      DECLARE
        next_seq INTEGER;
      BEGIN
        PERFORM 1 FROM journals
        WHERE journable_id = NEW.journable_id
          AND journable_type = NEW.journable_type
        FOR UPDATE;

        SELECT COALESCE(MAX(sequence_version), 0) + 1
        INTO next_seq
        FROM journals
        WHERE journable_id = NEW.journable_id
          AND journable_type = NEW.journable_type;

        NEW.sequence_version := next_seq;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL
      CREATE TRIGGER trigger_set_journal_sequence_version
      BEFORE INSERT ON journals
      FOR EACH ROW
      EXECUTE FUNCTION set_journal_sequence_version();
    SQL
  end

  def cleanup_failed_migration
    execute "DROP TRIGGER IF EXISTS trigger_set_journal_sequence_version ON journals;" rescue nil
    execute "DROP FUNCTION IF EXISTS set_journal_sequence_version();" rescue nil

    remove_index :journals, name: "index_journals_on_journable_and_sequence_version" rescue nil
    remove_column :journals, :sequence_version rescue nil
  end
end
