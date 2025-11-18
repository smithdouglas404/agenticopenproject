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
      new(project_storage, container).call(file_path:, filename:, file_data:)
    end

    def initialize(project_storage, container)
      super()
      @project_storage = project_storage
      @storage = project_storage.storage
      @container = container
      @user = determine_user(container)
    end

    def call(container:, file_path:, filename:, file_data:)
      with_tagged_logger do
        info "Starting file upload for #{filename} to #{file_path}"

        # TODO: do we need it?
        # auth_strategy = Adapters::Registry.resolve("#{storage}.authentication.user_bound").call(@user, storage)

        validate_storage_type(@storage).value_or { return @result }

        folder_id = ensure_folder_exists(file_path, @user).value_or { return @result }

        upload_result = upload_file(folder_id, filename, file_data, @user).value_or { return @result }
        create_file_link(container, upload_result, @user).value_or { return @result }

        @result
      end
    end

    private

    def validate_storage_type(storage)
      supported_types = %w[nextcloud one_drive sharepoint]

      unless supported_types.include?(storage.short_provider_type)
        return add_error(:base, :unsupported_storage_type, options: { storage_type: storage.short_provider_type })
      end

      Success()
    end

    def nextcloud_storage?
      @storage.short_provider_type == "nextcloud"
    end

    def determine_user(container)
      if container.is_a?(WorkPackage) && container.author.present?
        container.author
      else
        User.system
      end
    end

    def ensure_folder_exists(file_path)
      normalized_path = file_path.start_with?("/") ? file_path : "/#{file_path}"
      base_folder_id = @project_storage.project_folder_id.presence || get_root_folder_id

      return Failure(Results::Error.new(source: self.class).with(code: :not_found)) if base_folder_id.nil?

      folder_exists = check_folder_exists?(normalized_path, @user)

      if folder_exists
        Success(nextcloud_storage? ? normalized_path : base_folder_id)
      else
        create_folder_structure(normalized_path, base_folder_id, @user)
      end
    end

    def get_root_folder_id
      # For OneDrive/SharePoint, we need to get the drive root
      # This is typically handled by the storage configuration

      nextcloud_storage? ? "/" : nil
    end

    def check_folder_exists?(path)
      StorageFilesService.call(storage: @storage, user: @user, folder: path).success?
    end

    def create_folder(storage:, folder_name:, parent_id:)
      result = CreateFolderService.call(storage:, folder_name:, parent_id:, user: @user)
      return Failure(Results::Error.new(source: self.class).with(code: :error)) unless result.success?

      Success(result)
    end

    def create_folder_structure(path, base_folder_id, user)
      path_components = path.split("/").compact_blank
      current_folder_id = base_folder_id

      path_components.each do |folder_name|
        folder_path = "/#{path_components[0..path_components.index(folder_name)].join('/')}"
        exists = check_folder_exists?(folder_path, user)

        current_folder_id = if exists
                              nextcloud_storage? ? folder_path : base_folder_id
                            else
                              service_result = create_folder(storage: @storage, folder_name:,
                                                             parent_id: current_folder_id).value_or do
                                return Failure(Results::Error.new(source: self.class).with(code: :error))
                              end
                              service_result.result.id
                            end
      end

      Success(current_folder_id)
    end

    def upload_file_link(user:, storage:, upload_data:)
      upload_link_result = UploadLinkService.call(user:, storage:, upload_data:)

      unless upload_link_result.success?
        return Failure(Results::Error.new(source: self.class, payload: upload_link_result.errors).with(code: :error))
      end

      Success(upload_link_result.result)
    end

    def upload_file(folder_id, filename, file_data, user)
      # Check if adapter command is available (e.g., Nextcloud UploadFileCommand)
      if upload_command_available?
        # Use command directly - no need for upload link
        # Construct full file path: folder_id is already a path for Nextcloud, or folder ID for others
        full_file_path = if nextcloud_storage?
                           # For Nextcloud, folder_id is already a path like "/uploads/documents"
                           folder_id.end_with?("/") ? "#{folder_id}#{filename}" : "#{folder_id}/#{filename}"
                         else
                           # For other providers, we'd need to resolve folder_id to path
                           # For now, use folder_id as-is (may need adjustment when OneDrive/SharePoint implement command)
                           "#{folder_id}/#{filename}"
                         end

        upload_result = Files::UploadService.call(
          upload_link: nil, # Not needed when using command
          filename:,
          file_data:,
          storage: @storage,
          user:,
          file_path: full_file_path
        )
      else
        # Fall back to upload link + HTTP upload for providers without command
        upload_link_result = upload_file_link(user:,
                                              storage: @storage,
                                              upload_data: { folder_id:, file_name: filename })

        upload_link = upload_link_result.value_or { return Failure(upload_link_result.failure) }

        upload_result = Files::UploadService.call(
          upload_link:,
          filename:,
          file_data:,
          storage: @storage,
          user:,
          file_path: "#{folder_id}/#{filename}"
        )
      end

      upload_result.bind do |file_info|
        info "File uploaded successfully: #{file_info[:id]}"
        Success(file_info)
      end
    end

    def upload_command_available?
      Adapters::Registry.key?("#{@storage.short_provider_type}.commands.upload_file")
    rescue Adapters::Errors::UnknownProvider, Adapters::Errors::OperationNotSupported
      false
    end

    def create_file_link(container, file_info)
      info "Creating FileLink for file #{file_info[:id]}"

      file_link_params = {
        creator: @user,
        container:,
        origin_id: file_info[:id],
        origin_name: file_info[:name],
        origin_mime_type: file_info[:mime_type],
        storage: @storage
      }

      create_service = FileLinks::CreateService.new(user: @user, contract_class: FileLinks::CreateContract)
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
