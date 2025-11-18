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

require "net/http"
require "uri"

module Storages
  module Files
    class UploadService < BaseService
      using Peripherals::ServiceResultRefinements

      def self.call(upload_link:, filename:, file_data:, storage:, user:, file_path:)
        new(storage).call(upload_link:, filename:, file_data:, user:, file_path:)
      end

      def initialize(storage)
        super()
        @storage = storage
      end

      def call(upload_link:, filename:, file_data:, user:, file_path:)
        with_tagged_logger do
          # Try to use adapter command if available (e.g., Nextcloud UploadFileCommand)
          if command_available?
            upload_via_command(file_path:, filename:, file_data:, user:)
          elsif upload_link
            # Fall back to manual HTTP upload via upload link
            upload_via_link(upload_link:, filename:, file_data:)
          else
            Failure(Results::Error.new(source: self.class,
                                       payload: "No upload method available: command not available and no upload link provided").with(code: :error))
          end
        end
      end

      private

      def command_available?
        Adapters::Registry.key?("#{@storage.short_provider_type}.commands.upload_file")
      rescue Adapters::Errors::UnknownProvider, Adapters::Errors::OperationNotSupported
        false
      end

      def upload_via_command(file_path:, filename:, file_data:, user:)
        info "Using adapter command to upload file #{filename} to #{file_path}"

        input_data = Adapters::Input::UploadFile.build(file_path:, io: file_data).value_or do |error|
          return Failure(Results::Error.new(source: self.class, payload: error).with(code: :invalid))
        end

        auth_strategy = Adapters::Registry["#{@storage.short_provider_type}.authentication.user_bound"].call(user, @storage)

        Adapters::Registry["#{@storage.short_provider_type}.commands.upload_file"]
          .call(storage: @storage, auth_strategy:, input_data:)
          .bind do |storage_file|
            Success({
              id: storage_file.id.to_s,
              name: storage_file.name || filename,
              mime_type: storage_file.mime_type,
              size: storage_file.size
            })
          end
      end

      def upload_via_link(upload_link:, filename:, file_data:)
        info "Uploading file #{filename} to #{upload_link.destination} via upload link"

        uri = URI(upload_link.destination)

        case upload_link.method.to_s.downcase
        when "post"
          upload_via_post(uri, filename, file_data)
        when "put"
          upload_via_put(uri, filename, file_data)
        else
          Failure(Results::Error.new(source: self.class,
                                     payload: "Unsupported upload method: #{upload_link.method}").with(code: :error))
        end
      end

      def upload_via_post(uri, filename, file_data)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")

        request_path = uri.path
        request_path += "?#{uri.query}" if uri.query

        file_data.rewind

        request = Net::HTTP::Post.new(request_path)
        request.set_form([["file", file_data, { filename: }]], "multipart/form-data")

        response = http.request(request)

        case response
        when Net::HTTPSuccess
          parse_upload_response(response, filename)
        else
          Failure(Results::Error.new(source: self.class, payload: response).with(code: :error))
        end
      end

      def upload_via_put(uri, filename, file_data)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")

        file_data.rewind
        file_size = file_data.size
        file_data.rewind

        request_path = uri.path
        request_path += "?#{uri.query}" if uri.query

        request = Net::HTTP::Put.new(request_path)
        request["Content-Range"] = "bytes 0-#{file_size - 1}/#{file_size}"
        request["Content-Type"] = "application/octet-stream"
        request.body = file_data.read

        response = http.request(request)

        case response
        when Net::HTTPSuccess
          parse_upload_response(response, filename)
        else
          Failure(Results::Error.new(source: self.class, payload: response).with(code: :error))
        end
      end

      def parse_upload_response(response, filename)
        body = JSON.parse(response.body, symbolize_names: true)

        case @storage.short_provider_type
        when "nextcloud"
          Success({
                    id: body[:file_id].to_s,
                    name: body[:file_name] || filename,
                    mime_type: body[:mime_type],
                    size: body[:size]
                  })
        when "one_drive", "sharepoint"
          Success({
                    id: body[:id].to_s,
                    name: body[:name] || filename,
                    mime_type: body.dig(:file, :mimeType),
                    size: body[:size]
                  })
        else
          Failure(Results::Error.new(source: self.class, payload: "Unknown storage type").with(code: :error))
        end
      rescue JSON::ParserError => e
        Failure(Results::Error.new(source: self.class,
                                   payload: "Failed to parse upload response: #{e.message}").with(code: :error))
      end
    end
  end
end
