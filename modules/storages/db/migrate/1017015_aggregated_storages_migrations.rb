# frozen_string_literal: true

# -- copyright
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
# ++

require Rails.root.join("db/migrate/migration_utils/squashed_migration").to_s
require Rails.root.join("db/migrate/tables/base").to_s
Dir[File.join(__dir__, "tables/*.rb")].each { |file| require file }

class AggregatedStoragesMigrations < SquashedMigration
  squashed_migrations *%w[
    20220113144323_create_storage
    20220113144759_create_file_links
    20220121090847_create_projects_storages
    20220712165928_add_storages_permissions_to_roles
    20230123092649_make_containter_id_and_containter_type_optional_for_file_links
    20230321194150_add_project_folder_to_projects_storages
    20230420063148_add_provider_fields_to_storages
    20230420071113_migrate_storages_to_use_provider_type_as_sti_column
    20230512153303_change_storage_provider_fields_default
    20230517075214_add_automatic_to_project_folder_modes
    20230601082746_create_last_project_folders
    20230713144232_create_storages_file_link_journals
    20230721123022_remove_project_folder_mode_default
    20230802085026_rename_projects_storages_table
    20230824130730_remove_not_null_constraint_for_storage_host
    20231009135807_remove_renamed_cronjobs
    20231109080454_add_health_info_to_storages
    20231208143303_add_health_checked_at_to_storages
    20240405135016_update_access_management_of_configured_one_drive_storages
    20240610130953_rename_manage_storages_in_project_permission
    20230725165505_add_storage_name_to_storages_file_links_journals
    20230731153909_add_file_link_journals_to_existing_containers
  ].freeze

  tables Tables::Storages,
         Tables::FileLinks,
         Tables::ProjectStorages,
         Tables::LastProjectFolders,
         Tables::StoragesFileLinksJournals
end
