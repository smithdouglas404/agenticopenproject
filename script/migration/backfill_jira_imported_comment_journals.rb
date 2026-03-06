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
# 4) Optional scoped run (single/multiple projects):
#      PROJECTS=my-project,123 DRY_RUN=false bundle exec rails runner ...
#
# 5) Optional normalization-only pass:
#      NORMALIZE_ONLY=true DRY_RUN=false bundle exec rails runner ...
#
# 6) Verify remaining marker-prefixed import rows:
#      bundle exec rails runner "puts Journal.where(journable_type:'WorkPackage').where(\"notes ~ E'^[[:space:]]*\\\\[(COMMENT|HISTORY)\\\\]'\").count"
#
# 7) Verify unresolved mapping issues:
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
#   PROJECTS=identifier_or_id,...      optional
#   BATCH_SIZE=500                     default: 500
#   LIMIT=1000                         optional
#   STRIP_PREAMBLE=true|false          default: true
#   ALLOW_TIMESTAMP_ONLY=true|false    default: true (update date/body even if user cannot be mapped)
#   NORMALIZE_VALIDITY=true|false      default: true
#   NORMALIZE_MISMATCHED=true|false    default: true (also normalize pre-existing validity mismatches)
#   NORMALIZE_ONLY=true|false          default: false
#   SAMPLE_LIMIT=20                    default: 20
#
# Compatibility:
#   KEEP_PREAMBLE=true is equivalent to STRIP_PREAMBLE=false.

require "set"
require "time"

class JiraImportedCommentJournalBackfill
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

  attr_reader :dry_run,
              :batch_size,
              :limit,
              :project_filters,
              :strip_preamble,
              :allow_timestamp_only,
              :normalize_validity,
              :normalize_mismatched,
              :normalize_only,
              :sample_limit

  def initialize
    @dry_run = env_true?("DRY_RUN", default: true)
    @batch_size = ENV.fetch("BATCH_SIZE", "500").to_i
    @limit = ENV["LIMIT"]&.to_i
    @project_filters = ENV["PROJECTS"]&.split(",")&.map(&:strip)&.reject(&:blank?) || []

    @strip_preamble = !env_true?("KEEP_PREAMBLE", default: false)
    if ENV.key?("STRIP_PREAMBLE")
      @strip_preamble = env_true?("STRIP_PREAMBLE", default: true)
    end

    @allow_timestamp_only = env_true?("ALLOW_TIMESTAMP_ONLY", default: true)
    @normalize_validity = env_true?("NORMALIZE_VALIDITY", default: true)
    @normalize_mismatched = env_true?("NORMALIZE_MISMATCHED", default: true)
    @normalize_only = env_true?("NORMALIZE_ONLY", default: false)
    @sample_limit = ENV.fetch("SAMPLE_LIMIT", "20").to_i

    @user_id_cache = {}
  end

  def run!
    puts "Starting Jira imported activity backfill"
    puts "DRY_RUN=#{dry_run} BATCH_SIZE=#{batch_size} LIMIT=#{limit || 'none'} PROJECTS=#{project_filters.join(',').presence || 'all'}"
    puts "STRIP_PREAMBLE=#{strip_preamble} ALLOW_TIMESTAMP_ONLY=#{allow_timestamp_only}"
    puts "NORMALIZE_VALIDITY=#{normalize_validity} NORMALIZE_MISMATCHED=#{normalize_mismatched} NORMALIZE_ONLY=#{normalize_only}"

    touched_work_package_ids = Set.new
    stats = Hash.new(0)
    samples = Hash.new { |h, k| h[k] = [] }
    missing_user_emails = Hash.new(0)

    scope = candidate_scope
    puts "Candidate journals: #{scope.count}"

    unless normalize_only
      iterate_scope(scope) do |journal|
        status, parsed = parse_imported_activity(journal.notes)
        unless status == :ok
          stats[status] += 1
          append_sample(samples, status, journal.id)
          next
        end

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
    end

    print_summary(stats, samples, missing_user_emails)

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
    scope = Journal.where(journable_type: "WorkPackage")
                   .where("notes ~ E'^[[:space:]]*\\\\[(COMMENT|HISTORY)\\\\]'")
                   .joins("INNER JOIN work_packages ON work_packages.id = journals.journable_id")

    if project_filters.any?
      project_ids = resolve_project_ids(project_filters)
      raise "No matching projects for PROJECTS=#{project_filters.join(',')}" if project_ids.empty?

      scope = scope.where("work_packages.project_id IN (?)", project_ids)
    end

    scope = scope.limit(limit) if limit&.positive?
    scope
  end

  def iterate_scope(scope, &block)
    if limit&.positive?
      scope.each(&block)
    else
      scope.find_each(batch_size:, &block)
    end
  end

  def resolve_project_ids(filters)
    filters.filter_map do |token|
      if token.match?(/\A\d+\z/)
        token.to_i
      else
        Project.find_by(identifier: token)&.id
      end
    end.uniq
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

  def user_id_for_email(email)
    return @user_id_cache[email] if @user_id_cache.key?(email)

    @user_id_cache[email] = User.where("LOWER(mail) = ?", email).pick(:id)
  end

  def print_summary(stats, samples, missing_user_emails)
    puts "Summary: #{stats.sort_by { |k, _| k.to_s }.to_h.inspect}"

    samples.each do |key, values|
      next if values.empty?

      puts "#{key} sample: #{values.join(', ')}"
    end

    return if missing_user_emails.empty?

    puts "Top missing-user emails:"
    missing_user_emails.sort_by { |_, c| -c }.first(20).each do |email, count|
      puts "  #{email}: #{count}"
    end
  end

  def append_sample(samples, key, value)
    return if samples[key].size >= sample_limit

    samples[key] << value
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
    scope = Journal.where(journable_type: "WorkPackage")
                   .joins("INNER JOIN work_packages ON work_packages.id = journals.journable_id")
                   .where("lower(journals.validity_period) IS DISTINCT FROM journals.created_at")

    if project_filters.any?
      project_ids = resolve_project_ids(project_filters)
      raise "No matching projects for PROJECTS=#{project_filters.join(',')}" if project_ids.empty?

      scope = scope.where("work_packages.project_id IN (?)", project_ids)
    end

    scope.distinct.pluck(:journable_id)
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
