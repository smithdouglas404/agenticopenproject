#!/usr/bin/env ruby
# frozen_string_literal: true

# Backfill Jira groups and group memberships into OpenProject.
#
# This script assumes users already exist in OpenProject and will:
# - create missing groups from group_members_expanded.csv (and optionally groups.csv)
# - add users to those groups
#
# Usage:
#   bundle exec rails runner script/migration/backfill_jira_groups.rb
#
# Environment variables:
#   DRY_RUN=true|false                         default: true
#   GROUP_MEMBERS_CSV=/path/group_members_expanded.csv
#      default: /home/dev/srcs/jira_migration/jira_export/group_members_expanded.csv
#   GROUPS_CSV=/path/groups.csv                default: sibling groups.csv (if present)
#   USER_MAP_CSV=/path/jira_user_identity_map.csv
#      default: sibling openproject_backfill/jira_user_identity_map.csv (if present)
#   OUTPUT_DIR=/path/to/output                 default: sibling openproject_backfill
#   INCLUDE_EMPTY_GROUPS=true|false            default: true
#   FAIL_ON_MISSING_USERS=true|false           default: false

require "csv"
require "json"
require "pathname"
require "time"

# rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
class JiraGroupBackfill
  DEFAULT_GROUP_MEMBERS_CSV = "/home/dev/srcs/jira_migration/jira_export/group_members_expanded.csv"
  USER_TYPE = User.name
  DryRunGroup = Struct.new(:id, :lastname)

  attr_reader :dry_run,
              :group_members_csv,
              :groups_csv,
              :user_map_csv,
              :output_dir,
              :include_empty_groups,
              :fail_on_missing_users

  def initialize
    @dry_run = env_true?("DRY_RUN", default: true)
    @group_members_csv = Pathname.new(ENV.fetch("GROUP_MEMBERS_CSV", DEFAULT_GROUP_MEMBERS_CSV))

    export_dir = group_members_csv.dirname
    @groups_csv = Pathname.new(ENV.fetch("GROUPS_CSV", export_dir.join("groups.csv").to_s))
    @user_map_csv = Pathname.new(
      ENV.fetch("USER_MAP_CSV", export_dir.join("openproject_backfill/jira_user_identity_map.csv").to_s)
    )
    @output_dir = Pathname.new(ENV.fetch("OUTPUT_DIR", export_dir.join("openproject_backfill").to_s))
    @include_empty_groups = env_true?("INCLUDE_EMPTY_GROUPS", default: true)
    @fail_on_missing_users = env_true?("FAIL_ON_MISSING_USERS", default: false)

    @stats = Hash.new(0)
    @issues = []
    @group_cache = {}
    @user_map_index = {
      by_user_key: {},
      by_username: {},
      by_email: {}
    }
    @user_lookup_cache = {
      by_login: {},
      by_email: {}
    }
    @members_by_group_id = Hash.new { |hash, key| hash[key] = Set.new }
    @migration_user = User.unscoped.where(type: USER_TYPE, admin: true, status: Principal.statuses[:active]).first || User.system
    @next_dry_group_id = -1
  end

  def run!
    validate_paths!
    output_dir.mkpath unless output_dir.exist?
    load_user_map!

    puts "Starting Jira group backfill"
    puts "DRY_RUN=#{dry_run} INCLUDE_EMPTY_GROUPS=#{include_empty_groups} FAIL_ON_MISSING_USERS=#{fail_on_missing_users}"
    puts "GROUP_MEMBERS_CSV=#{group_members_csv}"
    puts "GROUPS_CSV=#{groups_csv} (exists=#{groups_csv.exist?})"
    puts "USER_MAP_CSV=#{user_map_csv} (exists=#{user_map_csv.exist?})"
    puts "OUTPUT_DIR=#{output_dir}"

    backfill_groups_only if include_empty_groups && groups_csv.exist?
    collect_memberships
    apply_memberships
    write_outputs
    print_summary
    fail_if_requested
  end

  private

  def env_true?(name, default:)
    raw = ENV.fetch(name, nil)
    return default if raw.nil?

    %w[1 true yes y on].include?(raw.to_s.strip.downcase)
  end

  def validate_paths!
    raise "Missing group membership CSV: #{group_members_csv}" unless group_members_csv.exist?
    raise "No admin/system user available to run group membership sync" if @migration_user.nil?
  end

  def load_user_map!
    return unless user_map_csv.exist?

    each_csv_row(user_map_csv) do |row|
      user_id = integer_or_nil(row["openproject_user_id"])
      next unless user_id
      next unless User.unscoped.exists?(type: USER_TYPE, id: user_id)

      map_key!(@user_map_index[:by_user_key], row["jira_user_key"], user_id)
      map_key!(@user_map_index[:by_username], row["jira_username"], user_id)
      map_key!(@user_map_index[:by_email], row["jira_email"], user_id)
      @stats[:user_map_rows_loaded] += 1
    end
  end

  def backfill_groups_only
    each_csv_row(groups_csv) do |row|
      group_name = clean(row["group_name"])
      next if group_name.blank?

      ensure_group(group_name)
    end
  end

  def collect_memberships
    each_csv_row(group_members_csv) do |row|
      group_name = clean(row["group_name"])
      if group_name.blank?
        @stats[:rows_skipped_blank_group] += 1
        next
      end

      group = ensure_group(group_name)
      unless group
        @stats[:rows_skipped_group_error] += 1
        next
      end

      user_id = resolve_user_id(row)
      unless user_id
        @stats[:rows_skipped_missing_user] += 1
        add_issue("membership", group_name, "user_not_found", compact_row(row))
        next
      end

      @members_by_group_id[group.id] << user_id
      @stats[:membership_rows_collected] += 1
    end
  end

  def ensure_group(name)
    key = normalize(name)
    cached = @group_cache[key]
    return cached if cached

    group = Group.unscoped.where("LOWER(lastname) = ?", key).first
    if group
      @stats[:groups_reused] += 1
      @group_cache[key] = group
      return group
    end

    if dry_run
      @stats[:groups_would_create] += 1
      dry_group = DryRunGroup.new(next_dry_group_id!, name)
      @group_cache[key] = dry_group
      return dry_group
    end

    group = Group.new
    group.type = Group.name
    group.lastname = name
    group.status = :active
    group.save!

    @stats[:groups_created] += 1
    @group_cache[key] = group
  rescue StandardError => e
    @stats[:groups_failed] += 1
    add_issue("group", name, e.message, { group_name: name })
    nil
  end

  def resolve_user_id(row)
    user_key = clean(row["user_key"])
    username = clean(row["username"])
    email = clean(row["email_address"])

    from_map = @user_map_index[:by_user_key][normalize(user_key)] if user_key.present?
    return from_map if from_map

    from_map = @user_map_index[:by_username][normalize(username)] if username.present?
    return from_map if from_map

    from_map = @user_map_index[:by_email][normalize(email)] if email.present?
    return from_map if from_map

    by_login = find_user_id_by_login(username)
    return by_login if by_login

    # Compatibility for users imported via backfill_jira_identities.rb.
    jira_prefixed = jira_prefixed_login(username)
    by_login = find_user_id_by_login(jira_prefixed)
    return by_login if by_login

    by_email = find_user_id_by_email(email)
    return by_email if by_email

    nil
  end

  def find_user_id_by_login(login)
    key = normalize(login)
    return nil if key.blank?

    return @user_lookup_cache[:by_login][key] if @user_lookup_cache[:by_login].key?(key)

    user_id = User.unscoped.where(type: USER_TYPE).where("LOWER(login) = ?", key).pick(:id)
    @user_lookup_cache[:by_login][key] = user_id
  end

  def find_user_id_by_email(email)
    key = normalize(email)
    return nil if key.blank?

    return @user_lookup_cache[:by_email][key] if @user_lookup_cache[:by_email].key?(key)

    user_id = User.unscoped.where(type: USER_TYPE).where("LOWER(mail) = ?", key).pick(:id)
    @user_lookup_cache[:by_email][key] = user_id
  end

  def jira_prefixed_login(username)
    return nil if username.blank?

    slug = username.to_s.downcase.gsub(/[^a-z0-9_\-@.+]+/, "_").gsub(/\A_+|_+\z/, "")
    slug = "jira_user" if slug.blank?
    "jira_#{slug}"[0, 256]
  end

  def apply_memberships
    @members_by_group_id.each do |group_id, user_ids_set|
      user_ids = user_ids_set.to_a
      next if user_ids.empty?

      if dry_run
        @stats[:memberships_would_apply] += user_ids.size
        next
      end

      group = Group.find_by(id: group_id)
      unless group
        @stats[:memberships_failed_missing_group] += user_ids.size
        add_issue("membership", group_id, "group_not_found_during_apply", { group_id:, user_ids_count: user_ids.size })
        next
      end

      existing_before = GroupUser.where(group_id:, user_id: user_ids).count

      call = Groups::AddUsersService
               .new(group, current_user: @migration_user)
               .call(ids: user_ids, send_notifications: false)

      if call.success?
        existing_after = GroupUser.where(group_id:, user_id: user_ids).count
        created = [existing_after - existing_before, 0].max
        @stats[:memberships_created] += created
        @stats[:memberships_existing_kept] += (user_ids.size - created)
      else
        @stats[:memberships_failed] += user_ids.size
        add_issue("membership", group.lastname, call.message, { group_id:, user_ids_count: user_ids.size })
      end
    rescue StandardError => e
      @stats[:memberships_failed] += user_ids.size
      add_issue("membership", group_id, e.message, { group_id:, user_ids_count: user_ids.size })
    end
  end

  def write_outputs
    write_group_map
    write_issues
    write_summary
  end

  def write_group_map
    path = output_dir.join("jira_group_map.csv")
    headers = %w[
      jira_group_name
      openproject_group_id
      openproject_group_name
    ]

    CSV.open(path, "wb", headers:, write_headers: true) do |csv|
      @group_cache.sort_by { |name, _group| name }.each do |normalized_name, group|
        jira_name = group&.lastname || normalized_name
        csv << [jira_name, persisted_group_id(group), group&.lastname]
      end
    end
  end

  def write_issues
    path = output_dir.join("jira_group_backfill_issues.csv")
    headers = %w[
      timestamp
      category
      key
      message
      details_json
    ]

    CSV.open(path, "wb", headers:, write_headers: true) do |csv|
      @issues.each do |issue|
        csv << [
          issue[:timestamp],
          issue[:category],
          issue[:key],
          issue[:message],
          issue[:details]
        ]
      end
    end
  end

  def write_summary
    path = output_dir.join("jira_group_backfill_summary.json")
    payload = {
      generated_at: Time.now.utc.iso8601,
      dry_run:,
      include_empty_groups:,
      fail_on_missing_users:,
      group_members_csv: group_members_csv.to_s,
      groups_csv: groups_csv.to_s,
      user_map_csv: user_map_csv.to_s,
      stats: @stats.sort.to_h
    }

    path.write("#{JSON.pretty_generate(payload)}\n")
  end

  def print_summary
    puts "\nSummary"
    puts "  Groups created: #{@stats[:groups_created]}"
    puts "  Groups reused: #{@stats[:groups_reused]}"
    puts "  Groups would create: #{@stats[:groups_would_create]}" if dry_run
    puts "  Membership rows collected: #{@stats[:membership_rows_collected]}"
    puts "  Memberships created: #{@stats[:memberships_created]}"
    puts "  Memberships existing kept: #{@stats[:memberships_existing_kept]}"
    puts "  Memberships would apply: #{@stats[:memberships_would_apply]}" if dry_run
    puts "  Missing users: #{@stats[:rows_skipped_missing_user]}"
    puts "  Issues: #{@issues.size}"
    puts "  Outputs:"
    puts "    #{output_dir.join('jira_group_map.csv')}"
    puts "    #{output_dir.join('jira_group_backfill_issues.csv')}"
    puts "    #{output_dir.join('jira_group_backfill_summary.json')}"
  end

  def fail_if_requested
    return unless fail_on_missing_users
    return unless @stats[:rows_skipped_missing_user].positive?

    raise "Missing users encountered: #{@stats[:rows_skipped_missing_user]}. " \
          "Check #{output_dir.join('jira_group_backfill_issues.csv')}"
  end

  def add_issue(category, key, message, details = {})
    @issues << {
      timestamp: Time.now.utc.iso8601,
      category:,
      key: key.to_s,
      message: message.to_s,
      details: JSON.generate(details)
    }
  end

  def persisted_group_id(group)
    return group.id if group.is_a?(Group)

    nil
  end

  def next_dry_group_id!
    current = @next_dry_group_id
    @next_dry_group_id -= 1
    current
  end

  def compact_row(row)
    {
      group_name: clean(row["group_name"]),
      username: clean(row["username"]),
      user_key: clean(row["user_key"]),
      email_address: clean(row["email_address"])
    }
  end

  def map_key!(index, raw_value, user_id)
    normalized = normalize(raw_value)
    return if normalized.blank?

    index[normalized] = user_id
  end

  def each_csv_row(path, &)
    CSV.foreach(path, headers: true, encoding: "bom|utf-8", &)
  end

  def clean(value)
    value.to_s.strip.presence
  end

  def normalize(value)
    value.to_s.strip.downcase
  end

  def integer_or_nil(value)
    Integer(value)
  rescue ArgumentError, TypeError
    nil
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity

JiraGroupBackfill.new.run!
