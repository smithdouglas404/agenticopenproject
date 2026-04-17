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

require "spec_helper"

RSpec.describe OpenProject::VisibilityCheckEnforcer do
  # Drive the enforcer with synthetic SQL payloads so tests don't depend on the
  # set of real tables present in the connection. We override `enforced_tables`
  # to a fixed list per spec.
  def enforce(sql, cached: false, name: "Meeting Load")
    described_class.enforce!(sql: sql, cached: cached, name: name)
  end

  around do |example|
    described_class.enforced_tables = %w[meetings work_packages]
    example.run
  ensure
    described_class.enforced_tables = nil
  end

  describe ".enforce!" do
    it "raises when an enforced table is referenced without any annotation" do
      expect { enforce(%(SELECT "meetings".* FROM "meetings")) }
        .to raise_error(OpenProject::VisibilityCheckMissing, /meetings/)
    end

    it "passes when the query carries the visibility_checked annotation for the referenced table" do
      sql = %(SELECT "meetings".* FROM "meetings" /* visibility_checked:meetings */)
      expect { enforce(sql) }.not_to raise_error
    end

    it "passes when an explicit skip_visibility_check is present for the referenced table" do
      sql = %(SELECT "meetings".* FROM "meetings" /* skip_visibility_check:meetings:admin-only */)
      expect { enforce(sql) }.not_to raise_error
    end

    it "ignores the query when no enforced table is referenced" do
      expect { enforce(%(SELECT "projects".* FROM "projects")) }.not_to raise_error
    end

    it "ignores cached queries" do
      expect { enforce(%(SELECT "meetings".* FROM "meetings"), cached: true) }.not_to raise_error
    end

    it "ignores SCHEMA queries" do
      expect { enforce(%(SELECT "meetings".* FROM "meetings"), name: "SCHEMA") }.not_to raise_error
    end

    it "ignores non-SELECT statements" do
      expect { enforce(%(UPDATE "meetings" SET name='x')) }.not_to raise_error
    end

    it "ignores table-like names that don't match a real enforced table (CTEs, aliases)" do
      # `visible_work_packages` is a CTE name; it's not in enforced_tables, so it must not trigger.
      sql = <<~SQL.squish
        WITH "visible_work_packages" AS (SELECT * FROM "meetings" /* visibility_checked:meetings */)
        SELECT * FROM "visible_work_packages"
      SQL
      expect { enforce(sql) }.not_to raise_error
    end

    context "with joined enforced tables" do
      let(:sql) do
        <<~SQL.squish
          SELECT "work_packages".* FROM "work_packages"
          INNER JOIN "meetings" ON "meetings"."project_id" = "work_packages"."project_id"
          /* visibility_checked:work_packages */
        SQL
      end

      it "raises naming the uncovered joined table" do
        expect { enforce(sql) }.to raise_error(OpenProject::VisibilityCheckMissing, /meetings/)
      end

      it "passes when both tables carry their annotation" do
        covered = "#{sql} /* visibility_checked:meetings */"
        expect { enforce(covered) }.not_to raise_error
      end

      it "passes when the joined table has an explicit skip annotation" do
        bypassed = "#{sql} /* skip_visibility_check:meetings:parent scope implies meeting visibility */"
        expect { enforce(bypassed) }.not_to raise_error
      end
    end

    context "with a subquery on an enforced table" do
      it "raises when the inner enforced table is not annotated" do
        sql = <<~SQL.squish
          SELECT "work_packages".* FROM "work_packages"
          WHERE "work_packages"."project_id" IN (SELECT "meetings"."project_id" FROM "meetings")
          /* visibility_checked:work_packages */
        SQL
        expect { enforce(sql) }.to raise_error(OpenProject::VisibilityCheckMissing, /meetings/)
      end

      it "passes when the inner annotation sits next to the inner SELECT" do
        sql = <<~SQL.squish
          SELECT "work_packages".* FROM "work_packages"
          WHERE "work_packages"."project_id" IN (SELECT "meetings"."project_id" FROM "meetings" /* visibility_checked:meetings */)
          /* visibility_checked:work_packages */
        SQL
        expect { enforce(sql) }.not_to raise_error
      end
    end

    context "when the enforcer has no enforced tables" do
      it "is a no-op" do
        described_class.enforced_tables = []
        expect { enforce(%(SELECT "meetings".* FROM "meetings")) }.not_to raise_error
      end
    end
  end

  describe ".bypass" do
    it "suppresses enforcement inside the block" do
      expect do
        described_class.bypass do
          enforce(%(SELECT "meetings".* FROM "meetings"))
        end
      end.not_to raise_error
    end

    it "restores enforcement after the block" do
      described_class.bypass { nil }
      expect { enforce(%(SELECT "meetings".* FROM "meetings")) }
        .to raise_error(OpenProject::VisibilityCheckMissing)
    end

    it "restores the previous bypass state even if the block raises" do
      expect do
        described_class.bypass do
          described_class.bypass { raise "boom" }
        end
      end.to raise_error("boom")
      expect(Thread.current[:visibility_check_bypass]).to be_nil
    end
  end

  describe "EXCLUDED_TABLES" do
    it "contains the framework, background-job, and configuration tables" do
      %w[
        ar_internal_metadata schema_migrations
        good_jobs good_job_batches good_job_executions good_job_processes good_job_settings
        sessions settings enabled_modules
        paper_trail_audits
      ].each do |table|
        expect(described_class::EXCLUDED_TABLES).to include(table)
      end
    end
  end

  describe "VisibilityAnnotation helpers" do
    it "adds a visibility_checked annotation via `.visibility_checked`" do
      sql = Meeting.all.visibility_checked.to_sql
      expect(sql).to include("/* visibility_checked:meetings */")
    end

    it "adds a skip_visibility_check annotation via `.skip_visibility_check(reason:)`" do
      sql = Meeting.skip_visibility_check(reason: "admin-only").to_sql
      expect(sql).to include("/* skip_visibility_check:meetings:admin-only */")
    end

    it "adds a scoped skip via `.skip_visibility_check_for(model, reason:)`" do
      sql = WorkPackage.all.skip_visibility_check_for(Meeting, reason: "parent covered").to_sql
      expect(sql).to include("/* skip_visibility_check:meetings:parent covered */")
    end

    it "requires a non-empty reason" do
      expect { Meeting.skip_visibility_check(reason: "") }.to raise_error(ArgumentError)
      expect { Meeting.skip_visibility_check(reason: "   ") }.to raise_error(ArgumentError)
    end
  end
end
