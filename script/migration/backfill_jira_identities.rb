#!/usr/bin/env ruby
# frozen_string_literal: true

# Backfill Jira identities (users, groups, group memberships) into OpenProject.
#
# Input defaults to CSV exports in:
#   /home/dev/srcs/jira_migration/jira_export
#
# Usage:
#   bundle exec rails runner script/migration/backfill_jira_identities.rb
#
# Environment variables:
#   DRY_RUN=true|false                  default: true
#   JIRA_EXPORT_DIR=/path/to/csvs       default: /home/dev/srcs/jira_migration/jira_export
#   OUTPUT_DIR=/path/to/output          default: <JIRA_EXPORT_DIR>/openproject_backfill
#   UPDATE_EXISTING_USERS=true|false    default: false
#   DEFAULT_EMAIL_DOMAIN=example.invalid default: example.invalid

require "csv"
require "json"
require "pathname"
require "securerandom"
require "set"
require "time"

class JiraIdentityBackfill
  DEFAULT_JIRA_EXPORT_DIR = "/home/dev/srcs/jira_migration/jira_export"
  DEFAULT_OUTPUT_SUBDIR = "openproject_backfill"
  USER_SOURCE_FILES = %w[
    users.csv
    group_members_expanded.csv
    user_group_memberships.csv
    project_member_roles_expanded.csv
    short_project_member_roles_expanded.csv
    project_role_actors_raw.csv
  ].freeze
  GROUP_SOURCE_FILES = %w[
    groups.csv
    group_members_expanded.csv
    user_group_memberships.csv
    project_member_roles_expanded.csv
    short_project_member_roles_expanded.csv
    project_role_actors_raw.csv
  ].freeze
  GROUP_MEMBERSHIP_FILES = %w[
    group_members_expanded.csv
    user_group_memberships.csv
  ].freeze
  EMAIL_REGEX = /\A[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\z/.freeze
  PENDING = :pending

  UserResult = Struct.new(:seed, :user, :action, :notes, keyword_init: true)
  GroupResult = Struct.new(:name, :group, :action, :notes, keyword_init: true)

  attr_reader :dry_run,
              :jira_export_dir,
              :output_dir,
              :update_existing_users,
              :default_email_domain

  def initialize
    @dry_run = env_true?("DRY_RUN", default: true)
    @jira_export_dir = Pathname.new(ENV.fetch("JIRA_EXPORT_DIR", DEFAULT_JIRA_EXPORT_DIR))
    @output_dir = Pathname.new(ENV.fetch("OUTPUT_DIR", jira_export_dir.join(DEFAULT_OUTPUT_SUBDIR).to_s))
    @update_existing_users = env_true?("UPDATE_EXISTING_USERS", default: false)
    @default_email_domain = ENV.fetch("DEFAULT_EMAIL_DOMAIN", "example.invalid")

    @stats = Hash.new(0)
    @issues = []
    @user_map_seed = {}
    @group_map_seed = {}
  end

  def run!
    validate_paths!
    load_existing_maps!

    puts "Starting Jira identity backfill"
    puts "DRY_RUN=#{dry_run} UPDATE_EXISTING_USERS=#{update_existing_users}"
    puts "JIRA_EXPORT_DIR=#{jira_export_dir}"
    puts "OUTPUT_DIR=#{output_dir}"

    user_seeds = collect_user_seeds
    group_names = collect_group_names
    membership_rows = collect_group_memberships

    user_results, user_index = upsert_users(user_seeds)
    group_results, group_index = upsert_groups(group_names)
    apply_group_memberships(membership_rows, user_index:, group_index:)

    write_outputs(user_results:, group_results:)
    print_summary
  end

  private

  def env_true?(name, default:)
    raw = ENV[name]
    return default if raw.nil?

    %w[1 true yes y on].include?(raw.to_s.strip.downcase)
  end

  def validate_paths!
    raise "JIRA export directory does not exist: #{jira_export_dir}" unless jira_export_dir.exist?
    raise "JIRA export path is not a directory: #{jira_export_dir}" unless jira_export_dir.directory?

    output_dir.mkpath unless output_dir.exist?
  end

  def load_existing_maps!
    user_map = output_dir.join("jira_user_identity_map.csv")
    group_map = output_dir.join("jira_group_map.csv")

    if user_map.exist?
      each_csv_row(user_map) do |row|
        user_id = integer_or_nil(row["openproject_user_id"])
        next unless user_id

        @user_map_seed[map_key("user_key", row["jira_user_key"])] = user_id
        @user_map_seed[map_key("username", row["jira_username"])] = user_id
        @user_map_seed[map_key("email", row["jira_email"])] = user_id
      end
    end

    if group_map.exist?
      each_csv_row(group_map) do |row|
        group_id = integer_or_nil(row["openproject_group_id"])
        next unless group_id

        @group_map_seed[normalize(row["jira_group_name"])] = group_id
      end
    end
  end

  def collect_user_seeds
    seeds = {}

    USER_SOURCE_FILES.each do |filename|
      path = jira_export_dir.join(filename)
      next unless path.exist?

      each_csv_row(path) do |row|
        attrs = extract_user_attributes(row, filename)
        next if attrs.values_at(:user_key, :username, :email).all?(&:blank?)

        key = user_seed_key(attrs)
        next unless key

        seed = (seeds[key] ||= {
          key:,
          user_key: nil,
          username: nil,
          email: nil,
          display_name: nil,
          active: nil,
          locale: nil,
          sources: Set.new
        })
        merge_user_seed!(seed, attrs, filename)
      end
    end

    seeds.values
  end

  def collect_group_names
    names = Set.new

    GROUP_SOURCE_FILES.each do |filename|
      path = jira_export_dir.join(filename)
      next unless path.exist?

      each_csv_row(path) do |row|
        group_name = first_present(
          row["group_name"],
          row["source_group"],
          row["actor_name"]
        )

        next if group_name.blank?

        # actor_name from raw actors can also be usernames. Guard by actor_type when present.
        actor_type = normalize(row["actor_type"])
        if filename == "project_role_actors_raw.csv" && !actor_type.include?("group")
          next
        end

        names << group_name.strip
      end
    end

    names.to_a.sort
  end

  def collect_group_memberships
    rows = []

    GROUP_MEMBERSHIP_FILES.each do |filename|
      path = jira_export_dir.join(filename)
      next unless path.exist?

      each_csv_row(path) do |row|
        group_name = row["group_name"].to_s.strip
        next if group_name.blank?

        attrs = extract_user_attributes(row, filename)
        next if attrs.values_at(:user_key, :username, :email).all?(&:blank?)

        rows << {
          source_file: filename,
          group_name:,
          user_key: attrs[:user_key],
          username: attrs[:username],
          email: attrs[:email]
        }
      end
    end

    rows
  end

  def extract_user_attributes(row, source_file)
    if source_file == "project_role_actors_raw.csv"
      {
        user_key: clean(row["expanded_user_key"]),
        username: clean(row["expanded_user_username"]),
        email: clean(row["expanded_user_email"]),
        display_name: clean(row["expanded_user_display_name"]),
        active: parse_bool(row["expanded_user_active"]),
        locale: nil
      }
    else
      {
        user_key: clean(row["user_key"]),
        username: clean(row["username"]),
        email: clean(row["email_address"]),
        display_name: clean(row["display_name"]),
        active: parse_bool(row["active"]),
        locale: clean(row["locale"])
      }
    end
  end

  def clean(value)
    value.to_s.strip.presence
  end

  def first_present(*values)
    values.each do |value|
      cleaned = clean(value)
      return cleaned if cleaned.present?
    end

    nil
  end

  def parse_bool(value)
    return nil if value.nil?

    normalized = value.to_s.strip.downcase
    return true if %w[true 1 yes y].include?(normalized)
    return false if %w[false 0 no n].include?(normalized)

    nil
  end

  def user_seed_key(attrs)
    return map_key("user_key", attrs[:user_key]) if attrs[:user_key].present?
    return map_key("username", attrs[:username]) if attrs[:username].present?
    return map_key("email", attrs[:email]) if attrs[:email].present?

    nil
  end

  def map_key(type, value)
    "#{type}:#{normalize(value)}"
  end

  def normalize(value)
    value.to_s.strip.downcase
  end

  def merge_user_seed!(seed, attrs, source)
    seed[:user_key] ||= attrs[:user_key]
    seed[:username] ||= attrs[:username]
    seed[:email] ||= attrs[:email]
    seed[:display_name] ||= attrs[:display_name]
    seed[:locale] ||= attrs[:locale]
    seed[:active] = attrs[:active] unless attrs[:active].nil?
    seed[:sources] << source
  end

  def upsert_users(user_seeds)
    results = []
    index = {
      by_user_key: {},
      by_username: {},
      by_email: {}
    }

    user_seeds.sort_by { |seed| [seed[:user_key].to_s, seed[:username].to_s, seed[:email].to_s] }.each do |seed|
      result = upsert_user(seed)
      results << result

      user = result.user
      resolved_id = user&.id
      resolved_id = PENDING if resolved_id.nil? && result.action == "would_create"
      next unless resolved_id

      index[:by_user_key][normalize(seed[:user_key])] = resolved_id if seed[:user_key].present?
      index[:by_username][normalize(seed[:username])] = resolved_id if seed[:username].present?
      index[:by_email][normalize(seed[:email])] = resolved_id if seed[:email].present?
    end

    [results, index]
  end

  def upsert_user(seed)
    existing = resolve_existing_user(seed)
    if existing
      if update_existing_users
        update_existing_user(existing, seed)
        @stats[:users_updated] += 1 unless dry_run
        @stats[:users_would_update] += 1 if dry_run
      else
        @stats[:users_existing_kept] += 1
      end

      return UserResult.new(seed:, user: existing, action: "reused", notes: nil)
    end

    user = build_new_user(seed)
    if dry_run
      @stats[:users_would_create] += 1
      return UserResult.new(seed:, user: nil, action: "would_create", notes: "login=#{user.login}")
    end

    user.save!
    @stats[:users_created] += 1
    UserResult.new(seed:, user:, action: "created", notes: nil)
  rescue StandardError => e
    @stats[:users_failed] += 1
    add_issue("user", seed[:key], e.message, seed)
    UserResult.new(seed:, user: nil, action: "error", notes: e.message)
  end

  def resolve_existing_user(seed)
    mapped_id = @user_map_seed[seed[:key]]
    if mapped_id
      mapped = find_user_by_id(mapped_id)
      return mapped if mapped
    end

    if seed[:email].present?
      user_by_email = find_user_by_email(seed[:email])
      return user_by_email if user_by_email
    end

    if seed[:username].present?
      candidate_login = base_login(seed)
      user_by_login = find_user_by_login(candidate_login)
      return user_by_login if user_by_login
    end

    nil
  end

  def find_user_by_id(id)
    User.unscoped.where(type: User.name).find_by(id:)
  end

  def find_user_by_email(email)
    return nil unless valid_email?(email)

    User.unscoped
        .where(type: User.name)
        .where("LOWER(mail) = ?", normalize(email))
        .first
  end

  def find_user_by_login(login)
    User.unscoped
        .where(type: User.name)
        .where("LOWER(login) = ?", normalize(login))
        .first
  end

  def update_existing_user(user, seed)
    attrs = {}
    firstname, lastname = split_name(seed[:display_name], seed[:username])
    attrs[:firstname] = firstname if user.firstname.blank? && firstname.present?
    attrs[:lastname] = lastname if user.lastname.blank? && lastname.present?
    attrs[:mail] = seed[:email] if user.mail.blank? && valid_email?(seed[:email])
    attrs[:language] = language_from_seed(seed) if user.language.blank?

    return if attrs.empty?
    return if dry_run

    user.assign_attributes(attrs)
    user.save!
  end

  def build_new_user(seed)
    firstname, lastname = split_name(seed[:display_name], seed[:username])
    login = unique_login(base_login(seed))
    mail = unique_mail(seed[:email], login:)

    user = User.new
    user.type = User.name
    user.login = login
    user.firstname = firstname
    user.lastname = lastname
    user.mail = mail
    user.status = seed[:active] == false ? :locked : :active
    user.language = language_from_seed(seed)
    user.first_login = false
    user.admin = false
    user.password = generated_password
    user.password_confirmation = user.password
    user
  end

  def split_name(display_name, username)
    raw = display_name.to_s.strip
    raw = username.to_s.strip if raw.blank?

    if raw.blank?
      return ["Jira", "User"]
    end

    parts = raw.split(/\s+/)
    if parts.length == 1
      [sanitize_name_part(parts.first, fallback: "Jira"),
       sanitize_name_part("User", fallback: "User")]
    else
      [sanitize_name_part(parts.first, fallback: "Jira"),
       sanitize_name_part(parts[1..].join(" "), fallback: "User")]
    end
  end

  def sanitize_name_part(value, fallback:)
    cleaned = value.to_s.gsub(/[^\p{Alnum}\p{Mark}\p{Space}'’´\-_.,@()+&*–]/, "").strip
    cleaned = fallback if cleaned.blank?
    cleaned[0, 256]
  end

  def language_from_seed(seed)
    locale = seed[:locale].to_s.strip
    return Setting.default_language if locale.blank?

    locale[0, 5]
  end

  def generated_password
    "Jm#{SecureRandom.base58(24)}1!"
  end

  def base_login(seed)
    basis = seed[:username].presence || seed[:user_key].presence || seed[:email].to_s.split("@").first.presence || "jira_user"
    slug = basis.downcase.gsub(/[^a-z0-9_\-@.+]+/, "_").gsub(/\A_+|_+\z/, "")
    slug = "jira_user" if slug.blank?
    "jira_#{slug}"[0, 256]
  end

  def unique_login(base)
    candidate = base[0, 256]
    suffix = 1

    while login_taken?(candidate)
      suffix += 1
      tail = "_#{suffix}"
      candidate = "#{base[0, 256 - tail.length]}#{tail}"
    end

    candidate
  end

  def login_taken?(login)
    User.unscoped.where(type: User.name).where("LOWER(login) = ?", normalize(login)).exists?
  end

  def unique_mail(email, login:)
    if valid_email?(email) && !mail_taken?(email)
      return email
    end

    suffix = 1
    loop do
      local = suffix == 1 ? login : "#{login}_#{suffix}"
      candidate = "#{local}@#{default_email_domain}"
      return candidate unless mail_taken?(candidate)

      suffix += 1
    end
  end

  def valid_email?(email)
    email.present? && EMAIL_REGEX.match?(email)
  end

  def mail_taken?(mail)
    User.unscoped.where(type: User.name).where("LOWER(mail) = ?", normalize(mail)).exists?
  end

  def upsert_groups(group_names)
    results = []
    index = {}

    group_names.each do |name|
      result = upsert_group(name)
      results << result
      group_id = result.group&.id
      group_id = PENDING if group_id.nil? && result.action == "would_create"
      index[normalize(name)] = group_id if group_id
    end

    [results, index]
  end

  def upsert_group(name)
    existing = resolve_existing_group(name)
    if existing
      @stats[:groups_existing_kept] += 1
      return GroupResult.new(name:, group: existing, action: "reused", notes: nil)
    end

    group = Group.new
    group.type = Group.name
    group.lastname = name
    group.status = :active

    if dry_run
      @stats[:groups_would_create] += 1
      return GroupResult.new(name:, group: nil, action: "would_create", notes: nil)
    end

    group.save!
    @stats[:groups_created] += 1
    GroupResult.new(name:, group:, action: "created", notes: nil)
  rescue StandardError => e
    @stats[:groups_failed] += 1
    add_issue("group", name, e.message, { group_name: name })
    GroupResult.new(name:, group: nil, action: "error", notes: e.message)
  end

  def resolve_existing_group(name)
    mapped_id = @group_map_seed[normalize(name)]
    if mapped_id
      mapped = Group.unscoped.find_by(id: mapped_id)
      return mapped if mapped
    end

    Group.unscoped.find_by(lastname: name) ||
      Group.unscoped.where("LOWER(lastname) = ?", normalize(name)).first
  end

  def apply_group_memberships(rows, user_index:, group_index:)
    rows.each do |row|
      group_id = group_index[normalize(row[:group_name])]
      if group_id.nil?
        @stats[:group_memberships_missing_group] += 1
        add_issue("group_membership", row[:source_file], "group_not_found", row)
        next
      end

      user_id = resolve_user_id_for_membership(row, user_index)
      if user_id.nil?
        @stats[:group_memberships_missing_user] += 1
        add_issue("group_membership", row[:source_file], "user_not_found", row)
        next
      end

      if dry_run
        @stats[:group_memberships_would_create] += 1
        next
      end

      if group_id == PENDING || user_id == PENDING
        @stats[:group_memberships_missing_dependency] += 1
        add_issue("group_membership", row[:source_file], "dependency_not_created", row)
        next
      end

      membership = GroupUser.find_or_create_by!(group_id:, user_id:)
      if membership.previous_changes.key?("id")
        @stats[:group_memberships_created] += 1
      else
        @stats[:group_memberships_existing_kept] += 1
      end
    rescue StandardError => e
      @stats[:group_memberships_failed] += 1
      add_issue("group_membership", row[:source_file], e.message, row)
    end
  end

  def resolve_user_id_for_membership(row, index)
    key = normalize(row[:user_key])
    id = index[:by_user_key][key] if key.present?
    return id if id

    username = normalize(row[:username])
    id = index[:by_username][username] if username.present?
    return id if id

    email = normalize(row[:email])
    id = index[:by_email][email] if email.present?
    return id if id

    if row[:email].present?
      user = find_user_by_email(row[:email])
      return user.id if user
    end

    nil
  end

  def write_outputs(user_results:, group_results:)
    write_user_map(user_results)
    write_group_map(group_results)
    write_issues
    write_summary
  end

  def write_user_map(user_results)
    path = output_dir.join("jira_user_identity_map.csv")
    headers = %w[
      jira_user_key
      jira_username
      jira_email
      jira_display_name
      jira_active
      openproject_user_id
      openproject_login
      openproject_mail
      action
      notes
      sources
    ]

    CSV.open(path, "wb", headers:, write_headers: true) do |csv|
      user_results.each do |result|
        seed = result.seed
        user = result.user
        csv << [
          seed[:user_key],
          seed[:username],
          seed[:email],
          seed[:display_name],
          seed[:active],
          user&.id,
          user&.login,
          user&.mail,
          result.action,
          result.notes,
          seed[:sources].to_a.sort.join(";")
        ]
      end
    end
  end

  def write_group_map(group_results)
    path = output_dir.join("jira_group_map.csv")
    headers = %w[
      jira_group_name
      openproject_group_id
      openproject_group_name
      action
      notes
    ]

    CSV.open(path, "wb", headers:, write_headers: true) do |csv|
      group_results.each do |result|
        csv << [
          result.name,
          result.group&.id,
          result.group&.lastname,
          result.action,
          result.notes
        ]
      end
    end
  end

  def write_issues
    path = output_dir.join("jira_identity_backfill_issues.csv")
    headers = %w[type context reason payload_json]

    CSV.open(path, "wb", headers:, write_headers: true) do |csv|
      @issues.each do |issue|
        csv << [
          issue[:type],
          issue[:context],
          issue[:reason],
          JSON.generate(issue[:payload])
        ]
      end
    end
  end

  def write_summary
    path = output_dir.join("jira_identity_backfill_summary.json")
    payload = {
      generated_at_utc: Time.now.utc.iso8601,
      dry_run:,
      jira_export_dir: jira_export_dir.to_s,
      output_dir: output_dir.to_s,
      stats: @stats.sort.to_h,
      issues_count: @issues.size
    }

    path.write(JSON.pretty_generate(payload))
  end

  def print_summary
    puts "Identity backfill summary:"
    @stats.sort.each do |key, value|
      puts "  #{key}: #{value}"
    end
    puts "  issues: #{@issues.size}"
    puts "Output:"
    puts "  #{output_dir.join('jira_user_identity_map.csv')}"
    puts "  #{output_dir.join('jira_group_map.csv')}"
    puts "  #{output_dir.join('jira_identity_backfill_issues.csv')}"
    puts "  #{output_dir.join('jira_identity_backfill_summary.json')}"
    puts(dry_run ? "Dry run complete. No DB rows were changed." : "Backfill complete.")
  end

  def add_issue(type, context, reason, payload)
    @issues << {
      type:,
      context:,
      reason:,
      payload:
    }
  end

  def each_csv_row(path, &block)
    CSV.foreach(path, headers: true, encoding: "bom|utf-8", &block)
  end

  def integer_or_nil(value)
    Integer(value)
  rescue ArgumentError, TypeError
    nil
  end
end

JiraIdentityBackfill.new.run!
