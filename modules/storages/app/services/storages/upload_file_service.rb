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

module Storages
  class UploadFileService < BaseService
    using Peripherals::ServiceResultRefinements

    def self.call(container:, project_storage:, file_path:, filename:, file_data:)
      new(project_storage).call(container:, file_path:, filename:, file_data:)
    end

    def initialize(project_storage)
      super()
      @project_storage = project_storage
      @storage = project_storage.storage
    end

    def call(container:, file_path:, filename:, file_data:)
      with_tagged_logger do
        info "Starting file upload for #{filename} to #{file_path}"

        user = determine_user(container)
        folder_id = ensure_folder_exists(file_path, user).value_or { return @result }

        upload_result = upload_file(folder_id, filename, file_data, user).value_or { return @result }

        create_file_link(container, upload_result, user).value_or { return @result }

        @result
      end
    end

    private

    def determine_user(container)
      if container.is_a?(WorkPackage) && container.author.present?
        container.author
      else
        User.system
      end
    end

    def ensure_folder_exists(file_path, user)
      info "Checking if folder exists at #{file_path}"

      normalized_path = file_path.start_with?("/") ? file_path : "/#{file_path}"
      base_folder_id = @project_storage.project_folder_id.presence || get_root_folder_id(user)

      return Failure(Results::Error.new(source: self.class).with(code: :not_found)) if base_folder_id.nil?

      folder_exists = check_folder_exists(normalized_path, base_folder_id, user)

      if folder_exists
        info "Folder already exists at #{normalized_path}"
        Success(get_folder_id_from_path(normalized_path, base_folder_id, user))
      else
        info "Folder does not exist, creating at #{normalized_path}"
        create_folder_structure(normalized_path, base_folder_id, user)
      end
    end

    def get_root_folder_id(user)
      case @storage.short_provider_type
      when "nextcloud"
        "/"
      when "one_drive", "sharepoint"
        # For OneDrive/SharePoint, we need to get the drive root
        # This is typically handled by the storage configuration
        nil
      else
        nil
      end
    end

    def check_folder_exists(path, base_folder_id, user)
      # Try to get file info for the path
      # For Nextcloud, we can use the path directly
      # For OneDrive/SharePoint, we need to navigate from base_folder_id

      case @storage.short_provider_type
      when "nextcloud"
        # For Nextcloud, try to list files in the folder
        result = StorageFilesService.call(storage: @storage, user:, folder: path)
        result.success?
      when "one_drive", "sharepoint"
        # For OneDrive/SharePoint, we'd need to navigate from base_folder_id
        # For now, assume it doesn't exist and create it
        false
      else
        false
      end
    end

    def get_folder_id_from_path(path, base_folder_id, user)
      case @storage.short_provider_type
      when "nextcloud"
        # For Nextcloud, the path itself can be used as folder_id
        path
      when "one_drive", "sharepoint"
        # For OneDrive/SharePoint, we'd need to resolve the path to an ID
        # This is complex and would require path-to-id mapping
        # For now, return base_folder_id
        base_folder_id
      else
        base_folder_id
      end
    end

    def create_folder_structure(path, base_folder_id, user)
      # Split the path into components
      path_components = path.split("/").reject(&:blank?)
      current_folder_id = base_folder_id

      path_components.each do |folder_name|
        # Check if this folder exists
        folder_path = "/#{path_components[0..path_components.index(folder_name)].join('/')}"
        exists = check_folder_exists(folder_path, base_folder_id, user)

        unless exists
          info "Creating folder: #{folder_name} in #{current_folder_id}"
          result = CreateFolderService.call(
            storage: @storage,
            user:,
            folder_name:,
            parent_id: current_folder_id
          )

          return Failure(Results::Error.new(source: self.class).with(code: :error)) unless result.success?

          current_folder_id = result.result.id
        else
          current_folder_id = get_folder_id_from_path(folder_path, base_folder_id, user)
        end
      end

      Success(current_folder_id)
    end

    def upload_file(folder_id, filename, file_data, user)
      info "Requesting upload link for #{filename} in folder #{folder_id}"

      upload_link_result = UploadLinkService.call(
        user:,
        storage: @storage,
        upload_data: { folder_id:, file_name: filename }
      )

      upload_link = upload_link_result.result.value_or { return Failure(upload_link_result.errors) }

      info "Uploading file to #{upload_link.destination}"

      upload_result = Files::UploadService.call(
        upload_link:,
        filename:,
        file_data:,
        storage: @storage
      )

      upload_result.bind do |file_info|
        info "File uploaded successfully: #{file_info[:id]}"
        Success(file_info)
      end
    end

    def create_file_link(container, file_info, user)
      info "Creating FileLink for file #{file_info[:id]}"

      creator = determine_user(container)

      file_link_params = {
        creator:,
        container:,
        origin_id: file_info[:id],
        origin_name: file_info[:name],
        origin_mime_type: file_info[:mime_type],
        storage: @storage
      }

      create_service = FileLinks::CreateService.new(user: creator, contract_class: FileLinks::CreateContract)
      result = create_service.call(file_link_params)

      if result.success?
        info "FileLink created successfully: #{result.result.id}"
        Success(result.result)
      else
        Failure(result.errors)
      end
    end
  end
end

