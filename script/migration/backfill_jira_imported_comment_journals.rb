#!/usr/bin/env ruby
# frozen_string_literal: true

# One-time backfill for Jira-imported work package activities written as:
#
# [HISTORY] 2026-02-24T23:30:25.093+0000
# Author: Jane Doe (jane.doe@example.com)
#
# * status: In Progress -> In Review
#
# or [COMMENT] in the same format.
#
# The script can:
# - map author email to OpenProject user and update journals.user_id
# - set journals.created_at / updated_at from embedded timestamp
# - strip the import preamble from notes
# - drop import-admin journals that only set Epic/Version (they corrupt chronology)
# - normalize journals.validity_period for touched work packages
#
# ---------------------------------------------------------------------------
# Operational Runbook
# ---------------------------------------------------------------------------
# 1) Backup first.
#    - Package install (DEB/RPM): sudo openproject run backup
#    - Source install: use your regular DB backup procedure.
#
# 2) Dry run (recommended first run).
#    - Package install (DEB/RPM):
#      sudo openproject run bundle exec rails runner /tmp/backfill_jira_imported_comment_journals.rb
#    - Source install:
#      bundle exec rails runner script/migration/backfill_jira_imported_comment_journals.rb
#
# 3) Apply changes.
#    - Package install (DEB/RPM):
#      sudo openproject run env DRY_RUN=false bundle exec rails runner /tmp/backfill_jira_imported_comment_journals.rb
#    - Source install:
#      DRY_RUN=false bundle exec rails runner script/migration/backfill_jira_imported_comment_journals.rb
#
# 4) Verify remaining marker-prefixed import rows:
#      bundle exec rails runner "puts Journal.where(journable_type:'WorkPackage').where(\"notes ~ E'^[[:space:]]*\\\\[(COMMENT|HISTORY)\\\\]'\").count"
#
# 5) Verify unresolved mapping issues:
#    Inspect script summary output:
#      - missing_user
#      - no_email
#      - parse_fail_*
# ---------------------------------------------------------------------------
#
# Usage:
#   bundle exec rails runner script/migration/backfill_jira_imported_comment_journals.rb
#
# Environment variables:
#   DRY_RUN=true|false                 default: true

require "set"
require "time"

class JiraImportedCommentJournalBackfill
  DEFAULT_BATCH_SIZE = 500
  DEFAULT_SAMPLE_LIMIT = 20
  DEFAULT_UNPARSABLE_DETAIL_LIMIT = 200

  ISO_TS_REGEX = /
    \d{4}-\d{2}-\d{2}
    T\d{2}:\d{2}:\d{2}
    (?:\.\d+)?
    (?:Z|[+-]\d{2}:?\d{2})
  /x.freeze

  EMAIL_REGEX = /[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/.freeze
  MARKER_START_REGEX = /\A[[:space:]\uFEFF]*\[(COMMENT|HISTORY)\]/i.freeze
  MARKER_ANY_REGEX = /\[(COMMENT|HISTORY)\]/i.freeze
  AUTHOR_LINE_REGEX = /^[[:space:]]*Author:[[:space:]]*(?<author>[^\r\n]*)/i.freeze
  IMPORTER_ONLY_DETAIL_KEYS = %w[version version_id epic epic_id].freeze

  attr_reader :dry_run,
              :batch_size,
              :strip_preamble,
              :allow_timestamp_only,
              :normalize_validity,
              :normalize_mismatched,
              :drop_unparsable_imported,
              :fix_initial_created_event,
              :align_initial_to_work_package,
              :sample_limit,
              :print_unparsable_details,
              :unparsable_detail_limit

  def initialize
    @dry_run = env_true?("DRY_RUN", default: true)
    @batch_size = DEFAULT_BATCH_SIZE
    @strip_preamble = true
    @allow_timestamp_only = true
    @normalize_validity = true
    @normalize_mismatched = true
    @drop_unparsable_imported = true
    @fix_initial_created_event = true
    @align_initial_to_work_package = true
    @sample_limit = DEFAULT_SAMPLE_LIMIT
    @print_unparsable_details = dry_run
    @unparsable_detail_limit = DEFAULT_UNPARSABLE_DETAIL_LIMIT

    @user_id_cache = {}
  end

  def run!
    puts "Starting Jira imported activity backfill"
    puts "DRY_RUN=#{dry_run} BATCH_SIZE=#{batch_size}"
    puts "Fixed behavior: STRIP_PREAMBLE=true ALLOW_TIMESTAMP_ONLY=true DROP_UNPARSABLE_IMPORTED=true"
    puts "Fixed behavior: FIX_INITIAL_CREATED_EVENT=true ALIGN_INITIAL_TO_WORK_PACKAGE=true"

    touched_work_package_ids = Set.new
    stats = Hash.new(0)
    samples = Hash.new { |h, k| h[k] = [] }
    missing_user_emails = Hash.new(0)
    unparsable_details = []
    creation_seed_by_work_package = {}

    scope = candidate_scope
    puts "Candidate journals: #{scope.count}"

    iterate_scope(scope) do |journal|
      status, parsed = parse_imported_activity(journal.notes)
      unless status == :ok
        stats[status] += 1
        append_sample(samples, status, journal.id)
        capture_unparsable_detail(unparsable_details, journal, status)

        if dry_run
          stats[:would_drop_unparsable] += 1
        else
          journal.destroy!
          stats[:dropped_unparsable] += 1
        end
        touched_work_package_ids << journal.journable_id
        next
      end

      track_creation_seed(creation_seed_by_work_package, journal, parsed)

      attrs = build_attrs(journal, parsed, stats:, missing_user_emails:)
      next if attrs.nil?

      if attrs.empty?
        stats[:already_aligned] += 1
        next
      end

      if dry_run
        stats[:would_update] += 1
      else
        journal.update_columns(attrs)
        stats[:updated] += 1
      end

      touched_work_package_ids << journal.journable_id
    rescue StandardError => e
      stats[:error] += 1
      append_sample(samples, :error, "#{journal.id}:#{e.class}:#{e.message}")
    end

    drop_import_admin_epic_version_entries!(
      touched_work_package_ids:,
      stats:,
      samples:
    )

    apply_initial_created_event_fix!(
      creation_seed_by_work_package:,
      touched_work_package_ids:,
      stats:,
      samples:
    )

    align_initial_journals_to_work_packages!(
      touched_work_package_ids:,
      stats:,
      samples:
    )

    print_summary(stats, samples, missing_user_emails, unparsable_details)

    if dry_run
      puts "Dry run complete. No data changed."
      return
    end

    return unless normalize_validity

    ids_to_normalize = touched_work_package_ids.to_a
    ids_to_normalize.concat(mismatched_validity_work_package_ids) if normalize_mismatched
    ids_to_normalize.uniq!

    puts "Work packages to normalize: #{ids_to_normalize.count}"
    normalize_stats = normalize_work_package_journals(ids_to_normalize)
    puts "Normalization stats: #{normalize_stats.inspect}"
    puts "Backfill complete."
  end

  private

  def candidate_scope
    Journal.where(journable_type: "WorkPackage")
           .where("notes ~ E'^[[:space:]]*\\\\[(COMMENT|HISTORY)\\\\]'")
           .joins("INNER JOIN work_packages ON work_packages.id = journals.journable_id")
  end

  def iterate_scope(scope, &block)
    scope.find_each(batch_size:, &block)
  end

  def parse_imported_activity(raw)
    text = normalize_text(raw)
    return [:parse_fail_no_marker, nil] unless MARKER_START_REGEX.match?(text)

    header = text[0, 3_000] || text
    timestamp_raw = header[ISO_TS_REGEX]
    return [:parse_fail_no_timestamp, nil] unless timestamp_raw

    timestamp = parse_timestamp(timestamp_raw)
    return [:parse_fail_bad_timestamp, nil] unless timestamp

    author_line = header.lines.find { |line| AUTHOR_LINE_REGEX.match?(line) }&.strip
    email = author_line&.match(EMAIL_REGEX)&.to_s&.downcase
    email ||= header.match(EMAIL_REGEX)&.to_s&.downcase

    body = if strip_preamble
             strip_import_preamble(text)
           else
             text
           end

    [:ok, { timestamp:, email:, body: }]
  end

  def strip_import_preamble(text)
    # Typical format:
    # [HISTORY] ...
    # Author: ...
    # <blank line>
    # body...
    strict = text.sub(/\A[[:space:]\uFEFF]*\[(?:COMMENT|HISTORY)\][^\n]*\n[[:space:]]*Author:[^\n]*\n+/im, "")
    return strict.sub(/\A[\n]+/, "") if strict != text

    # Fallback for malformed import rows:
    # find first marker then drop all text up to end of Author line.
    marker_idx = text =~ MARKER_ANY_REGEX
    return text if marker_idx.nil?

    sliced = text[marker_idx..]
    if (m = sliced.match(/Author:[^\n]*\n/im))
      (sliced[m.end(0)..] || "").sub(/\A[\n]+/, "")
    else
      # As a last fallback, strip only the first marker line.
      sliced.sub(/\A[^\n]*\n+/, "")
    end
  end

  def build_attrs(journal, parsed, stats:, missing_user_emails:)
    attrs = {}

    if journal.created_at != parsed[:timestamp]
      attrs[:created_at] = parsed[:timestamp]
      attrs[:updated_at] = parsed[:timestamp]
    elsif journal.updated_at != parsed[:timestamp]
      attrs[:updated_at] = parsed[:timestamp]
    end

    attrs[:notes] = parsed[:body] if journal.notes != parsed[:body]

    if parsed[:email].present?
      user_id = user_id_for_email(parsed[:email])

      if user_id
        attrs[:user_id] = user_id if journal.user_id != user_id
      else
        stats[:missing_user] += 1
        missing_user_emails[parsed[:email]] += 1
        return nil unless allow_timestamp_only
      end
    else
      stats[:no_email] += 1
      return nil unless allow_timestamp_only
    end

    attrs
  end

  def track_creation_seed(creation_seed_by_work_package, journal, parsed)
    work_package_id = journal.journable_id
    mapped_user_id = parsed[:email].present? ? user_id_for_email(parsed[:email]) : nil

    candidate = {
      timestamp: parsed[:timestamp],
      user_id: mapped_user_id,
      email: parsed[:email],
      source_journal_id: journal.id
    }

    existing = creation_seed_by_work_package[work_package_id]

    if existing.nil? ||
       candidate[:timestamp] < existing[:timestamp] ||
       (candidate[:timestamp] == existing[:timestamp] && existing[:user_id].nil? && candidate[:user_id].present?)
      creation_seed_by_work_package[work_package_id] = candidate
    end
  end

  def apply_initial_created_event_fix!(creation_seed_by_work_package:, touched_work_package_ids:, stats:, samples:)
    puts "Work packages with parsed imported activity: #{creation_seed_by_work_package.count}"

    creation_seed_by_work_package.each do |work_package_id, seed|
      apply_initial_created_event_fix_for_work_package!(
        work_package_id:,
        seed:,
        touched_work_package_ids:,
        stats:,
        samples:
      )
    rescue StandardError => e
      stats[:initial_fix_error] += 1
      append_sample(samples, :initial_fix_error, "wp=#{work_package_id}:#{e.class}:#{e.message}")
    end
  end

  def apply_initial_created_event_fix_for_work_package!(work_package_id:, seed:, touched_work_package_ids:, stats:, samples:)
    initial_journal = Journal.where(journable_type: "WorkPackage", journable_id: work_package_id)
                             .order(:version, :id)
                             .select(:id, :user_id, :created_at, :updated_at)
                             .first
    unless initial_journal
      stats[:missing_initial_journal] += 1
      append_sample(samples, :missing_initial_journal, work_package_id)
      return
    end

    work_package = WorkPackage.where(id: work_package_id)
                              .select(:id, :author_id, :created_at)
                              .first
    unless work_package
      stats[:missing_work_package] += 1
      append_sample(samples, :missing_work_package, work_package_id)
      return
    end

    journal_attrs = {}
    if initial_journal.created_at != seed[:timestamp]
      journal_attrs[:created_at] = seed[:timestamp]
      journal_attrs[:updated_at] = seed[:timestamp]
    elsif initial_journal.updated_at != seed[:timestamp]
      journal_attrs[:updated_at] = seed[:timestamp]
    end

    if seed[:user_id].present?
      journal_attrs[:user_id] = seed[:user_id] if initial_journal.user_id != seed[:user_id]
    else
      stats[:initial_missing_user] += 1
      append_sample(samples,
                    :initial_missing_user,
                    "wp=#{work_package_id} email=#{seed[:email] || 'none'} source_journal=#{seed[:source_journal_id]}")
      return unless allow_timestamp_only
    end

    work_package_attrs = {}
    work_package_attrs[:created_at] = seed[:timestamp] if work_package.created_at != seed[:timestamp]
    if seed[:user_id].present? && work_package.author_id != seed[:user_id]
      work_package_attrs[:author_id] = seed[:user_id]
    end

    journal_changed = journal_attrs.any?
    work_package_changed = work_package_attrs.any?

    if journal_changed
      if dry_run
        stats[:would_update_initial_journal] += 1
      else
        Journal.where(id: initial_journal.id).update_all(journal_attrs)
        stats[:updated_initial_journal] += 1
      end
      touched_work_package_ids << work_package_id if journal_attrs.key?(:created_at) || journal_attrs.key?(:updated_at)
    end

    if work_package_changed
      if dry_run
        stats[:would_update_work_package_created_event] += 1
      else
        WorkPackage.where(id: work_package.id).update_all(work_package_attrs)
        stats[:updated_work_package_created_event] += 1
      end
    end

    return if journal_changed || work_package_changed

    stats[:initial_created_event_already_aligned] += 1
  end

  def drop_import_admin_epic_version_entries!(touched_work_package_ids:, stats:, samples:)
    admin_user_ids = importer_admin_user_ids

    if admin_user_ids.empty?
      puts "Importer admin user not found; skipping import-admin epic/version cleanup."
      return
    end

    scope = Journal.where(journable_type: "WorkPackage", user_id: admin_user_ids)
                   .where("version > 1")
                   .where("COALESCE(notes, '') = ''")

    puts "Potential import-admin journals (empty note): #{scope.count}"

    iterate_scope(scope) do |journal|
      changed_keys = journal.details.keys.map(&:to_s)
      next if changed_keys.empty?
      next unless changed_keys.all? { |key| IMPORTER_ONLY_DETAIL_KEYS.include?(key) }

      append_sample(samples, :import_admin_epic_version, journal.id)
      if dry_run
        stats[:would_drop_import_admin_epic_version] += 1
      else
        journal.destroy!
        stats[:dropped_import_admin_epic_version] += 1
      end
      touched_work_package_ids << journal.journable_id
    rescue StandardError => e
      stats[:import_admin_epic_version_error] += 1
      append_sample(samples, :import_admin_epic_version_error, "#{journal.id}:#{e.class}:#{e.message}")
    end
  end

  def importer_admin_user_ids
    @importer_admin_user_ids ||= begin
      ids = User.where("LOWER(firstname) = 'openproject' AND LOWER(lastname) = 'admin'").pluck(:id)
      ids = User.where("LOWER(login) = 'admin'").pluck(:id) if ids.empty?
      ids.uniq
    end
  end

  def align_initial_journals_to_work_packages!(touched_work_package_ids:, stats:, samples:)
    scope = mismatched_initial_journals_scope
    count = scope.count
    puts "Initial journals misaligned with work packages: #{count}"
    return if count.zero?

    sample_ids = scope.limit(sample_limit).pluck("journals.id")
    sample_ids.each { |id| append_sample(samples, :initial_wp_alignment, id) }

    if dry_run
      stats[:would_align_initial_from_work_package] += count
      return
    end

    scope.select("journals.id, journals.journable_id, work_packages.author_id AS wp_author_id, work_packages.created_at AS wp_created_at")
         .find_each(batch_size:) do |journal|
      attrs = {
        created_at: journal.wp_created_at,
        updated_at: journal.wp_created_at
      }
      attrs[:user_id] = journal.wp_author_id if journal.wp_author_id.present?

      Journal.where(id: journal.id).update_all(attrs)
      stats[:aligned_initial_from_work_package] += 1
      touched_work_package_ids << journal.journable_id
    end
  end

  def mismatched_initial_journals_scope
    Journal.where(journable_type: "WorkPackage", version: 1)
           .joins("INNER JOIN work_packages ON work_packages.id = journals.journable_id")
           .where("work_packages.author_id IS NOT NULL")
           .where(<<~SQL.squish)
             journals.user_id IS DISTINCT FROM work_packages.author_id
             OR journals.created_at IS DISTINCT FROM work_packages.created_at
             OR journals.updated_at IS DISTINCT FROM work_packages.created_at
           SQL
  end

  def user_id_for_email(email)
    return @user_id_cache[email] if @user_id_cache.key?(email)

    @user_id_cache[email] = User.where("LOWER(mail) = ?", email).pick(:id)
  end

  def print_summary(stats, samples, missing_user_emails, unparsable_details)
    puts "Summary: #{stats.sort_by { |k, _| k.to_s }.to_h.inspect}"

    samples.each do |key, values|
      next if values.empty?

      puts "#{key} sample: #{values.join(', ')}"
    end

    unless missing_user_emails.empty?
      puts "Top missing-user emails:"
      missing_user_emails.sort_by { |_, c| -c }.first(20).each do |email, count|
        puts "  #{email}: #{count}"
      end
    end

    print_unparsable_details_report(unparsable_details, stats)
  end

  def append_sample(samples, key, value)
    return if samples[key].size >= sample_limit

    samples[key] << value
  end

  def capture_unparsable_detail(unparsable_details, journal, status)
    return unless dry_run && print_unparsable_details
    return if unparsable_detail_limit.positive? && unparsable_details.size >= unparsable_detail_limit

    text = normalize_text(journal.notes)
    first_line = text.lines.first.to_s.strip[0, 300]
    preview = text.gsub(/\s+/, " ").strip[0, 500]

    unparsable_details << {
      id: journal.id,
      work_package_id: journal.journable_id,
      version: journal.version,
      reason: status,
      first_line:,
      preview:
    }
  end

  def print_unparsable_details_report(unparsable_details, stats)
    return unless dry_run && print_unparsable_details

    total_parse_fails = stats.sum do |k, v|
      k.to_s.start_with?("parse_fail_") ? v : 0
    end
    return if total_parse_fails.zero?

    shown = unparsable_details.count
    limit_label = unparsable_detail_limit.positive? ? unparsable_detail_limit : "none"
    puts "Unparsable imported journals (dry run): showing #{shown}/#{total_parse_fails} (limit=#{limit_label})"

    unparsable_details.each do |detail|
      puts "  id=#{detail[:id]} work_package_id=#{detail[:work_package_id]} version=#{detail[:version]} reason=#{detail[:reason]}"
      puts "    first_line=#{detail[:first_line].inspect}"
      puts "    preview=#{detail[:preview].inspect}"
    end
  end

  def normalize_work_package_journals(work_package_ids)
    stats = Hash.new(0)

    work_package_ids.each_with_index do |work_package_id, idx|
      begin
        normalize_work_package_journals!(work_package_id)
        stats[:normalized] += 1
      rescue StandardError => e
        stats[:failed] += 1
        puts "  failed work_package_id=#{work_package_id}: #{e.class}: #{e.message}"
      end

      if ((idx + 1) % 100).zero?
        puts "  normalized #{idx + 1}/#{work_package_ids.count} work packages"
      end
    end

    stats
  end

  def normalize_work_package_journals!(work_package_id)
    Journal.transaction do
      ActiveRecord::Base.connection.execute("SET CONSTRAINTS non_overlapping_journals_validity_periods DEFERRED")

      journals = Journal.where(journable_type: "WorkPackage", journable_id: work_package_id)
                        .order(:version, :id)
                        .select(:id, :created_at, :updated_at)
                        .to_a
      return if journals.empty?

      last_time = nil
      journals.each do |journal|
        new_time = journal.created_at
        new_time = plus_one_microsecond(last_time) if last_time && new_time <= last_time

        if new_time != journal.created_at
          new_updated_at = [journal.updated_at, new_time].max
          Journal.where(id: journal.id).update_all(created_at: new_time, updated_at: new_updated_at)
          journal.created_at = new_time
        end

        last_time = journal.created_at
      end

      sql = <<~SQL
        WITH ordered AS (
          SELECT id,
                 created_at,
                 lead(created_at) OVER (ORDER BY version, id) AS next_created_at
          FROM journals
          WHERE journable_type = 'WorkPackage'
            AND journable_id = #{work_package_id.to_i}
        )
        UPDATE journals AS j
        SET validity_period = tstzrange(o.created_at, o.next_created_at, '[)')
        FROM ordered AS o
        WHERE j.id = o.id
      SQL
      ActiveRecord::Base.connection.execute(sql)

      WorkPackage.where(id: work_package_id).update_all(updated_at: last_time)
    end
  end

  def mismatched_validity_work_package_ids
    Journal.where(journable_type: "WorkPackage")
           .joins("INNER JOIN work_packages ON work_packages.id = journals.journable_id")
           .where("lower(journals.validity_period) IS DISTINCT FROM journals.created_at")
           .distinct
           .pluck(:journable_id)
  end

  def normalize_text(raw)
    text = raw.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    text.gsub(/\r\n?/, "\n")
  end

  def parse_timestamp(raw)
    value = raw.to_s.strip.sub(/([+-]\d{2})(\d{2})\z/, "\\1:\\2")
    Time.iso8601(value).in_time_zone
  rescue ArgumentError
    nil
  end

  def plus_one_microsecond(time)
    Time.zone.at(time.to_r + Rational(1, 1_000_000))
  end

  def env_true?(name, default:)
    value = ENV[name]
    return default if value.nil?

    ActiveModel::Type::Boolean.new.cast(value)
  end
end

JiraImportedCommentJournalBackfill.new.run!
