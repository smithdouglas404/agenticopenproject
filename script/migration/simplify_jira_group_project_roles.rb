#!/usr/bin/env ruby
# frozen_string_literal: true

# Simplify Jira project role management in OpenProject by:
# 1) assigning mapped project roles to Jira groups on each project and
# 2) removing redundant direct user roles when the same role is inherited via group membership.
#
# Usage:
#   bundle exec rails runner script/migration/simplify_jira_group_project_roles.rb
#
# Environment variables:
#   DRY_RUN=true|false                         default: true
#   JIRA_EXPORT_DIR=/path/to/jira_export       default: /home/dev/srcs/jira_migration/jira_export
#   PROJECT_ROLE_ACTORS_CSV=/path/to/project_role_actors_raw.csv
#      default: <JIRA_EXPORT_DIR>/project_role_actors_raw.csv
#   GROUP_MEMBERS_CSV=/path/to/group_members_expanded.csv
#      default: <JIRA_EXPORT_DIR>/group_members_expanded.csv
#   OUTPUT_DIR=/path/to/output                 default: <JIRA_EXPORT_DIR>/openproject_backfill
#   PROJECT_MAPPING_CSV=/path/to/project_mapping.csv
#      default: <OUTPUT_DIR>/project_mapping.csv (optional)
#   GROUP_MAP_CSV=/path/to/jira_group_map.csv
#      default: <OUTPUT_DIR>/jira_group_map.csv (optional)
#   USER_MAP_CSV=/path/to/jira_user_identity_map.csv
#      default: <OUTPUT_DIR>/jira_user_identity_map.csv (optional)
#   ROLE_MAPPING_CSV=/path/to/jira_role_mapping.csv
#      optional: overrides built-in Jira role mapping by jira_role_name
#   SYNC_GROUP_INHERITED_ROLES=true|false      default: true
#   REMOVE_REDUNDANT_DIRECT_ROLES=true|false   default: true

require "csv"
require "json"
require "pathname"
require "time"

# rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
class JiraGroupProjectRoleSimplifier
  DEFAULT_JIRA_EXPORT_DIR = "/home/dev/srcs/jira_migration/jira_export"
  DEFAULT_OUTPUT_SUBDIR = "openproject_backfill"
  USER_TYPE = User.name
  ISSUE_CATEGORY = "jira_group_project_role_simplification"
  SYNC_MESSAGE = "Jira group role simplification"

  DEFAULT_ROLE_NAME_MAPPING = {
    "administrators" => "Project admin",
    "contributor" => "Member",
    "developer" => "Member",
    "manager" => "Project admin",
    "notifier-full" => "Reader",
    "notifier-important" => "Reader",
    "notifier-minimal" => "Reader",
    "reporter" => "Member",
    "service desk customers" => "Member",
    "service desk team" => "Member",
    "viewer" => "Reader"
  }.freeze

  attr_reader :dry_run,
              :jira_export_dir,
              :project_role_actors_csv,
              :group_members_csv,
              :output_dir,
              :project_mapping_csv,
              :group_map_csv,
              :user_map_csv,
              :role_mapping_csv,
              :sync_group_inherited_roles,
              :remove_redundant_direct_roles

  def initialize
    @dry_run = env_true?("DRY_RUN", default: true)
    @jira_export_dir = Pathname.new(ENV.fetch("JIRA_EXPORT_DIR", DEFAULT_JIRA_EXPORT_DIR))
    @project_role_actors_csv = Pathname.new(
      ENV.fetch("PROJECT_ROLE_ACTORS_CSV", jira_export_dir.join("project_role_actors_raw.csv").to_s)
    )
    @group_members_csv = Pathname.new(
      ENV.fetch("GROUP_MEMBERS_CSV", jira_export_dir.join("group_members_expanded.csv").to_s)
    )
    @output_dir = Pathname.new(ENV.fetch("OUTPUT_DIR", jira_export_dir.join(DEFAULT_OUTPUT_SUBDIR).to_s))
    @project_mapping_csv = Pathname.new(
      ENV.fetch("PROJECT_MAPPING_CSV", output_dir.join("project_mapping.csv").to_s)
    )
    @group_map_csv = Pathname.new(
      ENV.fetch("GROUP_MAP_CSV", output_dir.join("jira_group_map.csv").to_s)
    )
    @user_map_csv = Pathname.new(
      ENV.fetch("USER_MAP_CSV", output_dir.join("jira_user_identity_map.csv").to_s)
    )

    # Use built-in mapping by default; optionally override through CSV.
    role_mapping_override = ENV.fetch("ROLE_MAPPING_CSV", "").strip
    @role_mapping_csv = role_mapping_override.present? ? Pathname.new(role_mapping_override) : nil

    @sync_group_inherited_roles = env_true?("SYNC_GROUP_INHERITED_ROLES", default: true)
    @remove_redundant_direct_roles = env_true?("REMOVE_REDUNDANT_DIRECT_ROLES", default: true)

    @stats = Hash.new(0)
    @issues = []
    @applied_rows = []
    @project_lookup_cache = {}
    @group_lookup_cache = {}
    @role_lookup_cache = {}
    @user_lookup_cache = {
      by_login: {},
      by_email: {}
    }

    @migration_user = User.unscoped
                          .where(type: USER_TYPE, admin: true, status: Principal.statuses[:active])
                          .first || User.system
  end

  def run!
    validate_paths!
    output_dir.mkpath unless output_dir.exist?

    puts "Starting Jira group role simplification"
    puts "DRY_RUN=#{dry_run}"
    puts "SYNC_GROUP_INHERITED_ROLES=#{sync_group_inherited_roles}"
    puts "REMOVE_REDUNDANT_DIRECT_ROLES=#{remove_redundant_direct_roles}"
    puts "PROJECT_ROLE_ACTORS_CSV=#{project_role_actors_csv}"
    puts "GROUP_MEMBERS_CSV=#{group_members_csv}"
    puts "PROJECT_MAPPING_CSV=#{project_mapping_csv} (exists=#{project_mapping_csv.exist?})"
    puts "GROUP_MAP_CSV=#{group_map_csv} (exists=#{group_map_csv.exist?})"
    puts "USER_MAP_CSV=#{user_map_csv} (exists=#{user_map_csv.exist?})"
    puts "ROLE_MAPPING_CSV=#{role_mapping_csv} (exists=#{role_mapping_csv&.exist?})"

    role_name_mapping = load_role_name_mapping
    project_mapping = load_project_mapping
    group_mapping = load_group_mapping
    user_index = load_user_index
    group_member_index = load_group_member_index(user_index)
    assignments = collect_group_assignments(role_name_mapping)

    puts "Collected unique group assignments: #{assignments.length}"

    assignments.each do |assignment|
      process_assignment(
        assignment:,
        project_mapping:,
        group_mapping:,
        group_member_index:
      )
    end

    write_outputs
    print_summary
  end

  private

  def env_true?(name, default:)
    raw = ENV.fetch(name, nil)
    return default if raw.nil?

    %w[1 true yes y on].include?(raw.to_s.strip.downcase)
  end

  def validate_paths!
    if using_default_input_paths? && !jira_export_dir.exist?
      raise([
        "JIRA export directory does not exist: #{jira_export_dir}.",
        "Set JIRA_EXPORT_DIR or provide PROJECT_ROLE_ACTORS_CSV and GROUP_MEMBERS_CSV explicitly."
      ].join(" "))
    end

    raise "Missing project role actor CSV: #{project_role_actors_csv}" unless project_role_actors_csv.exist?
    raise "Missing group members CSV: #{group_members_csv}" unless group_members_csv.exist?
    raise "No admin/system user available to run group role sync" if @migration_user.nil?
    return unless role_mapping_csv && !role_mapping_csv.exist?

    raise "ROLE_MAPPING_CSV does not exist: #{role_mapping_csv}"
  end

  def using_default_input_paths?
    ENV.fetch("PROJECT_ROLE_ACTORS_CSV", nil).blank? && ENV.fetch("GROUP_MEMBERS_CSV", nil).blank?
  end

  def load_role_name_mapping
    mapping = DEFAULT_ROLE_NAME_MAPPING.dup
    return mapping if role_mapping_csv.nil?

    each_csv_row(role_mapping_csv) do |row|
      next unless row_enabled?(row)

      jira_role_name = clean(row["jira_role_name"])
      next if jira_role_name.blank?

      openproject_role_name = clean(row["openproject_role_name"]) || clean(row["recommended_openproject_role_name"])
      next if openproject_role_name.blank?

      mapping[normalize(jira_role_name)] = openproject_role_name
      @stats[:role_mapping_overrides_loaded] += 1
    end

    mapping
  end

  def load_project_mapping
    by_jira_key = {}
    by_jira_id = {}
    return { by_jira_key:, by_jira_id: } unless project_mapping_csv.exist?

    each_csv_row(project_mapping_csv) do |row|
      next unless row_enabled?(row)

      jira_key = clean(row["jira_project_key"])
      jira_id = clean(row["jira_project_id"])
      entry = {
        openproject_project_id: integer_or_nil(row["openproject_project_id"]),
        openproject_project_identifier: clean(row["openproject_project_identifier"])
      }

      by_jira_key[normalize(jira_key)] = entry if jira_key.present?
      by_jira_id[normalize(jira_id)] = entry if jira_id.present?
      @stats[:project_mapping_rows_loaded] += 1
    end

    { by_jira_key:, by_jira_id: }
  end

  def load_group_mapping
    by_jira_group_name = {}
    return { by_jira_group_name: } unless group_map_csv.exist?

    each_csv_row(group_map_csv) do |row|
      jira_group_name = clean(row["jira_group_name"])
      next if jira_group_name.blank?

      by_jira_group_name[normalize(jira_group_name)] = {
        openproject_group_id: integer_or_nil(row["openproject_group_id"]),
        openproject_group_name: clean(row["openproject_group_name"])
      }
      @stats[:group_mapping_rows_loaded] += 1
    end

    { by_jira_group_name: }
  end

  def load_user_index
    by_user_key = {}
    by_username = {}
    by_email = {}

    return { by_user_key:, by_username:, by_email: } unless user_map_csv.exist?

    each_csv_row(user_map_csv) do |row|
      user_id = integer_or_nil(row["openproject_user_id"])
      next unless user_id
      next unless User.unscoped.where(type: USER_TYPE).exists?(id: user_id)

      map_key!(by_user_key, row["jira_user_key"], user_id)
      map_key!(by_username, row["jira_username"], user_id)
      map_key!(by_email, row["jira_email"], user_id)
      @stats[:user_mapping_rows_loaded] += 1
    end

    { by_user_key:, by_username:, by_email: }
  end

  def load_group_member_index(user_index)
    index = Hash.new { |hash, key| hash[key] = Set.new }

    each_csv_row(group_members_csv) do |row|
      group_name = clean(row["group_name"])
      if group_name.blank?
        @stats[:group_member_rows_skipped_blank_group] += 1
        next
      end

      user_id = resolve_user_id(
        user_key: clean(row["user_key"]),
        username: clean(row["username"]),
        email: clean(row["email_address"]),
        user_index:
      )

      if user_id.nil?
        @stats[:group_member_rows_missing_user] += 1
        add_issue(
          "group_members",
          group_name,
          "user_not_found",
          compact_row(row)
        )
        next
      end

      index[normalize(group_name)] << user_id
      @stats[:group_member_rows_loaded] += 1
    end

    index
  end

  def collect_group_assignments(role_name_mapping)
    assignments = {}

    each_csv_row(project_role_actors_csv) do |row|
      actor_source = normalize(row["actor_source"])
      actor_type = normalize(row["actor_type"])
      next unless actor_source == "direct_group" || actor_type.include?("group")

      jira_group_name = clean(row["actor_name"])
      jira_role_name = clean(row["role_name"])
      project_key = clean(row["project_key"])
      project_id = clean(row["project_id"])
      project_name = clean(row["project_name"])

      if jira_group_name.blank? || jira_role_name.blank? || (project_key.blank? && project_id.blank?)
        @stats[:actor_rows_skipped_incomplete] += 1
        next
      end

      mapped_role_name = role_name_mapping[normalize(jira_role_name)]
      if mapped_role_name.blank?
        @stats[:actor_rows_skipped_unmapped_role] += 1
        add_issue(
          "actor_row",
          "#{project_key || project_id}|#{jira_group_name}",
          "jira_role_not_mapped",
          compact_row(row)
        )
        next
      end

      key = [
        normalize(project_key),
        normalize(project_id),
        normalize(jira_group_name),
        normalize(mapped_role_name)
      ].join("|")

      assignment = (assignments[key] ||= {
        key:,
        project_key:,
        project_id:,
        project_name:,
        jira_group_name:,
        mapped_role_name:,
        jira_role_names: Set.new
      })

      assignment[:jira_role_names] << jira_role_name
      @stats[:actor_rows_consumed] += 1
    end

    assignments.values.sort_by do |row|
      [
        normalize(row[:project_key]),
        normalize(row[:project_id]),
        normalize(row[:jira_group_name]),
        normalize(row[:mapped_role_name])
      ]
    end
  end

  def process_assignment(assignment:, project_mapping:, group_mapping:, group_member_index:)
    project = resolve_project(assignment, project_mapping)
    return unless project

    group = resolve_group(assignment, group_mapping)
    return unless group

    role = resolve_role(assignment[:mapped_role_name])
    unless role
      @stats[:assignments_missing_role] += 1
      add_issue("assignment", assignment[:key], "openproject_role_not_found", assignment_payload(assignment))
      return
    end

    member, role_add_action = ensure_group_project_role(project:, group:, role:, assignment:)
    return unless member

    if sync_group_inherited_roles
      sync_ok = sync_inherited_group_roles(group:, member:)
      unless sync_ok
        @stats[:assignments_group_sync_failed] += 1
        # Cleanup may still run for already inherited memberships.
      end
    end

    if remove_redundant_direct_roles
      cleanup_redundant_direct_roles(
        project:,
        group:,
        role:,
        assignment:,
        group_member_index:
      )
    end

    @stats[:assignments_processed] += 1

    log_applied(
      phase: "group_role_assignment",
      assignment:,
      project_id: project.id,
      group_id: group.id,
      role_id: role.id,
      user_id: nil,
      action: role_add_action
    )
  rescue StandardError => e
    @stats[:assignments_failed] += 1
    add_issue("assignment", assignment[:key], e.message, assignment_payload(assignment))
  end

  def resolve_project(assignment, project_mapping)
    jira_key = normalize(assignment[:project_key])
    jira_id = normalize(assignment[:project_id])

    cache_key = "#{jira_key}|#{jira_id}"
    return @project_lookup_cache[cache_key] if @project_lookup_cache.key?(cache_key)

    mapping_entry = project_mapping[:by_jira_key][jira_key] if jira_key.present?
    mapping_entry ||= project_mapping[:by_jira_id][jira_id] if jira_id.present?

    project = nil
    if mapping_entry
      op_project_id = mapping_entry[:openproject_project_id]
      op_identifier = mapping_entry[:openproject_project_identifier]
      project = Project.find_by(id: op_project_id) if op_project_id
      project ||= find_project_by_identifier(op_identifier) if op_identifier.present?
    end

    project ||= find_project_by_identifier(assignment[:project_key]) if assignment[:project_key].present?
    project ||= Project.find_by(id: integer_or_nil(assignment[:project_id])) if assignment[:project_id].present?

    if project.nil? && assignment[:project_name].present?
      project = Project.where("LOWER(name) = ?", normalize(assignment[:project_name])).first
    end

    unless project
      @stats[:assignments_missing_project] += 1
      add_issue("assignment", assignment[:key], "project_not_found", assignment_payload(assignment))
      @project_lookup_cache[cache_key] = nil
      return nil
    end

    @project_lookup_cache[cache_key] = project
  end

  def find_project_by_identifier(identifier)
    key = normalize(identifier)
    return nil if key.blank?

    Project.where("LOWER(identifier) = ?", key).first
  end

  def resolve_group(assignment, group_mapping)
    jira_group_name = assignment[:jira_group_name]
    key = normalize(jira_group_name)
    return @group_lookup_cache[key] if @group_lookup_cache.key?(key)

    mapping = group_mapping[:by_jira_group_name][key]
    group = nil

    if mapping
      group_id = mapping[:openproject_group_id]
      op_group_name = mapping[:openproject_group_name]
      group = Group.unscoped.find_by(id: group_id) if group_id
      group ||= find_group_by_name(op_group_name) if op_group_name.present?
    end

    group ||= find_group_by_name(jira_group_name)

    unless group
      @stats[:assignments_missing_group] += 1
      add_issue("assignment", assignment[:key], "group_not_found", assignment_payload(assignment))
      @group_lookup_cache[key] = nil
      return nil
    end

    @group_lookup_cache[key] = group
  end

  def find_group_by_name(group_name)
    normalized_name = normalize(group_name)
    return nil if normalized_name.blank?

    Group.unscoped.where("LOWER(lastname) = ?", normalized_name).first
  end

  def resolve_role(openproject_role_name)
    key = normalize(openproject_role_name)
    return @role_lookup_cache[key] if @role_lookup_cache.key?(key)

    role = ProjectRole.where("LOWER(name) = ?", key).first
    role ||= Role.where("LOWER(name) = ?", key).find { |candidate| candidate.member? && candidate.is_a?(ProjectRole) }
    @role_lookup_cache[key] = role
  end

  def ensure_group_project_role(project:, group:, role:, assignment:)
    member = Member.find_or_initialize_by(
      project_id: project.id,
      user_id: group.id,
      entity_type: nil,
      entity_id: nil
    )

    new_member = member.new_record?
    if new_member
      if dry_run
        @stats[:group_members_would_create] += 1
      else
        member.save!(validate: false)
        @stats[:group_members_created] += 1
      end
    else
      @stats[:group_members_existing] += 1
    end

    existing_direct_role_ids = if member.persisted?
                                 member.member_roles.where(inherited_from: nil).pluck(:role_id).to_set
                               else
                                 Set.new
                               end

    if existing_direct_role_ids.include?(role.id)
      @stats[:group_roles_existing] += 1
      action = dry_run ? "would_keep_group_role" : "kept_group_role"
      return [member, action]
    end

    if dry_run
      @stats[:group_roles_would_add] += 1
      return [member, "would_add_group_role"]
    end

    MemberRole.find_or_create_by!(member_id: member.id, role_id: role.id, inherited_from: nil)
    @stats[:group_roles_added] += 1
    [member, "added_group_role"]
  rescue StandardError => e
    @stats[:group_role_apply_failed] += 1
    add_issue("assignment", assignment[:key], e.message, assignment_payload(assignment))
    [nil, "failed"]
  end

  def sync_inherited_group_roles(group:, member:)
    return true if dry_run

    user_ids = group.user_ids

    create_result = Groups::CreateInheritedRolesService
                    .new(group, current_user: @migration_user, contract_class: EmptyContract)
                    .call(
                      user_ids:,
                      project_ids: [member.project_id],
                      send_notifications: false,
                      message: SYNC_MESSAGE
                    )

    unless create_result.success?
      @stats[:group_sync_create_failed] += 1
      add_issue(
        "group_sync",
        "#{group.id}|#{member.project_id}",
        create_result.message,
        { group_id: group.id, project_id: member.project_id, mode: "create_inherited_roles" }
      )
      return false
    end

    update_result = Groups::UpdateRolesService
                    .new(group, current_user: @migration_user, contract_class: EmptyContract)
                    .call(
                      member:,
                      send_notifications: false,
                      message: SYNC_MESSAGE
                    )

    unless update_result.success?
      @stats[:group_sync_update_failed] += 1
      add_issue(
        "group_sync",
        "#{group.id}|#{member.project_id}",
        update_result.message,
        { group_id: group.id, project_id: member.project_id, mode: "update_roles" }
      )
      return false
    end

    @stats[:group_sync_success] += 1
    true
  rescue StandardError => e
    @stats[:group_sync_exception] += 1
    add_issue(
      "group_sync",
      "#{group.id}|#{member.project_id}",
      e.message,
      { group_id: group.id, project_id: member.project_id }
    )
    false
  end

  def cleanup_redundant_direct_roles(project:, group:, role:, assignment:, group_member_index:)
    user_ids = group_user_ids_for_cleanup(group:, jira_group_name: assignment[:jira_group_name], group_member_index:)
    if user_ids.empty?
      @stats[:cleanup_skipped_empty_group_users] += 1
      add_issue(
        "cleanup",
        assignment[:key],
        "group_has_no_resolved_users",
        assignment_payload(assignment)
      )
      return
    end

    user_ids.each do |user_id|
      remove_user_direct_role_if_redundant(
        project:,
        role:,
        assignment:,
        group:,
        user_id:
      )
    end
  end

  def group_user_ids_for_cleanup(group:, jira_group_name:, group_member_index:)
    csv_user_ids = group_member_index[normalize(jira_group_name)].to_a
    db_user_ids = group.user_ids

    (csv_user_ids + db_user_ids).uniq
  end

  def remove_user_direct_role_if_redundant(project:, role:, assignment:, group:, user_id:)
    member = Member.find_by(
      project_id: project.id,
      user_id: user_id,
      entity_type: nil,
      entity_id: nil
    )
    return unless member

    direct_scope = member.member_roles.where(inherited_from: nil, role_id: role.id)
    direct_count = direct_scope.count
    return if direct_count.zero?

    if dry_run
      @stats[:direct_roles_would_remove] += direct_count
      log_applied(
        phase: "cleanup_direct_role",
        assignment:,
        project_id: project.id,
        group_id: group.id,
        role_id: role.id,
        user_id:,
        action: "would_remove_direct_user_role"
      )
      return
    end

    inherited_exists = member.member_roles.where(role_id: role.id).where.not(inherited_from: nil).exists?
    unless inherited_exists
      @stats[:direct_roles_kept_missing_inherited] += direct_count
      add_issue(
        "cleanup",
        "#{project.id}|#{user_id}|#{role.id}",
        "missing_inherited_role",
        {
          project_id: project.id,
          user_id:,
          role_id: role.id,
          group_id: group.id,
          assignment_key: assignment[:key]
        }
      )
      return
    end

    removed = direct_scope.delete_all
    return if removed.zero?

    @stats[:direct_roles_removed] += removed
    log_applied(
      phase: "cleanup_direct_role",
      assignment:,
      project_id: project.id,
      group_id: group.id,
      role_id: role.id,
      user_id:,
      action: "removed_direct_user_role"
    )
  rescue StandardError => e
    @stats[:cleanup_failed] += 1
    add_issue(
      "cleanup",
      "#{project.id}|#{user_id}|#{role.id}",
      e.message,
      {
        project_id: project.id,
        user_id:,
        role_id: role.id,
        group_id: group.id,
        assignment_key: assignment[:key]
      }
    )
  end

  def resolve_user_id(user_key:, username:, email:, user_index:)
    if user_key.present?
      user_id = user_index[:by_user_key][normalize(user_key)]
      return user_id if user_id
    end

    if username.present?
      user_id = user_index[:by_username][normalize(username)]
      return user_id if user_id
    end

    if email.present?
      user_id = user_index[:by_email][normalize(email)]
      return user_id if user_id
    end

    user_id = find_user_id_by_login(username)
    return user_id if user_id

    user_id = find_user_id_by_login(jira_prefixed_login(username))
    return user_id if user_id

    user_id = find_user_id_by_email(email)
    return user_id if user_id

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

  def map_key!(index, value, user_id)
    key = normalize(value)
    return if key.blank?

    index[key] = user_id
  end

  def write_outputs
    write_applied_rows
    write_issues
    write_summary
  end

  def write_applied_rows
    path = output_dir.join("jira_group_project_role_simplification_applied.csv")
    headers = %w[
      phase
      jira_project_key
      jira_project_id
      jira_group_name
      jira_role_names
      mapped_openproject_role_name
      openproject_project_id
      openproject_group_id
      openproject_role_id
      openproject_user_id
      action
      dry_run
    ]

    CSV.open(path, "wb", headers:, write_headers: true) do |csv|
      @applied_rows.each do |row|
        csv << headers.map { |header| row[header.to_sym] }
      end
    end
  end

  def write_issues
    path = output_dir.join("jira_group_project_role_simplification_issues.csv")
    headers = %w[
      timestamp
      category
      context
      reason
      payload_json
    ]

    CSV.open(path, "wb", headers:, write_headers: true) do |csv|
      @issues.each do |issue|
        csv << [
          issue[:timestamp],
          issue[:category],
          issue[:context],
          issue[:reason],
          JSON.generate(issue[:payload])
        ]
      end
    end
  end

  def write_summary
    path = output_dir.join("jira_group_project_role_simplification_summary.json")
    payload = {
      generated_at_utc: Time.now.utc.iso8601,
      dry_run:,
      jira_export_dir: jira_export_dir.to_s,
      project_role_actors_csv: project_role_actors_csv.to_s,
      group_members_csv: group_members_csv.to_s,
      output_dir: output_dir.to_s,
      sync_group_inherited_roles:,
      remove_redundant_direct_roles:,
      stats: @stats.sort.to_h,
      issues_count: @issues.size
    }

    path.write(JSON.pretty_generate(payload))
  end

  def print_summary
    puts "Jira group role simplification summary:"
    @stats.sort.each do |key, value|
      puts "  #{key}: #{value}"
    end
    puts "  issues: #{@issues.size}"
    puts "Output:"
    puts "  #{output_dir.join('jira_group_project_role_simplification_applied.csv')}"
    puts "  #{output_dir.join('jira_group_project_role_simplification_issues.csv')}"
    puts "  #{output_dir.join('jira_group_project_role_simplification_summary.json')}"
    puts(dry_run ? "Dry run complete. No DB rows were changed." : "Simplification complete.")
  end

  def log_applied(phase:, assignment:, project_id:, group_id:, role_id:, user_id:, action:)
    @applied_rows << {
      phase:,
      jira_project_key: assignment[:project_key],
      jira_project_id: assignment[:project_id],
      jira_group_name: assignment[:jira_group_name],
      jira_role_names: assignment[:jira_role_names].to_a.sort.join(";"),
      mapped_openproject_role_name: assignment[:mapped_role_name],
      openproject_project_id: project_id,
      openproject_group_id: group_id,
      openproject_role_id: role_id,
      openproject_user_id: user_id,
      action:,
      dry_run: dry_run
    }
  end

  def add_issue(category, context, reason, payload)
    @issues << {
      timestamp: Time.now.utc.iso8601,
      category: "#{ISSUE_CATEGORY}:#{category}",
      context: context.to_s,
      reason: reason.to_s,
      payload:
    }
  end

  def assignment_payload(assignment)
    {
      project_key: assignment[:project_key],
      project_id: assignment[:project_id],
      project_name: assignment[:project_name],
      jira_group_name: assignment[:jira_group_name],
      jira_role_names: assignment[:jira_role_names].to_a.sort,
      mapped_role_name: assignment[:mapped_role_name]
    }
  end

  def compact_row(row)
    row.to_h.transform_values { |v| clean(v) }.compact_blank
  end

  def each_csv_row(path, &)
    CSV.foreach(path, headers: true, encoding: "bom|utf-8", &)
  end

  def row_enabled?(row)
    enabled = clean(row["enabled"])
    return true if enabled.blank?

    %w[0 false no n off].exclude?(normalize(enabled))
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

JiraGroupProjectRoleSimplifier.new.run!
