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

    # container - WorkPackage or other journaled model
    # TODO: file_data IO?
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

    def call(file_path:, filename:, file_data:)
      with_tagged_logger do
        info "Starting file upload for #{filename} to #{file_path}"

        unless nextcloud_storage?
          @result.errors.add(:base, :unsupported_storage_type)
          @result.success = false
          return @result
        end

        folder = get_folder!(auth_strategy, file_path).value_or { return @result }
        file = upload_file(auth_strategy, folder, filename, file_data).value_or { return @result }
        file_link = create_file_link(file).value_or { return @result }

        @result.success(file_link)
        @result
      end
    end

    private

    def auth_strategy = Adapters::Registry["nextcloud.authentication.userless"].call

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

    def get_folder!(auth_strategy, file_path)
      prefix = @project_storage.managed_project_folder_path
      normalized_path = prefix + (file_path.start_with?("/") ? file_path[1...] : file_path)

      folder_result = check_folder_exists?(auth_strategy, normalized_path)

      folder_result.value_or do |error|
        if error.code == :not_found
          return create_folder!(auth_strategy, normalized_path)
        else
          return Failure(error)
        end
      end

      Success(folder_result.parent)
    end

    def check_folder_exists?(auth_strategy, path)
      input_data = Adapters::Input::Files.build(folder: path).value_or do |error|
        add_validation_error(error, options: { folder: path })
      end

      Adapters::Registry.resolve("#{@storage}.queries.files").call(auth_strategy:, storage: @storage, input_data:)
    end

    def create_folder!(auth_strategy, path)
      folder_path = File.dirname(path)
      folder_name = path.sub("#{folder_path}/", "")

      input_data = Adapters::Input::CreateFolder.build(folder_name:, parent_location: folder_path).value_or do |error|
        add_validation_error(error, options: { folder_id: folder_path })
      end
      Adapters::Registry["#{@storage}.commands.create_folder"]
        .call(storage: @storage, auth_strategy: auth_strategy, input_data:).bind do |created_folder|
          Success(created_folder)
        end
    end

    def upload_file(auth_strategy, folder, filename, file_data)
      input_data = Adapters::Input::UploadFile.build(file_path: "#{folder.location}/#{filename}",
                                                     io: file_data).value_or do |error|
        add_validation_error(error, options: { file_path: "#{folder.location}/#{filename}" })
      end

      Adapters::Registry["#{@storage.short_provider_type}.commands.upload_file"]
        .call(storage: @storage, auth_strategy:, input_data:)
    end

    def create_file_link(file_info)
      info "Creating FileLink for file #{file_info.id}"

      file_link_params = {
        creator: @user,
        container: @container,
        origin_id: file_info.id,
        origin_name: file_info.name,
        origin_mime_type: file_info.mime_type,
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
