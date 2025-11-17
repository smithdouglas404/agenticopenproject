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

      def self.call(upload_link:, filename:, file_data:, storage:)
        new(storage).call(upload_link:, filename:, file_data:)
      end

      def initialize(storage)
        super()
        @storage = storage
      end

      def call(upload_link:, filename:, file_data:)
        with_tagged_logger do
          info "Uploading file #{filename} to #{upload_link.destination}"

          uri = URI(upload_link.destination)

          case upload_link.method.to_s.downcase
          when "post"
            upload_via_post(uri, filename, file_data)
          when "put"
            upload_via_put(uri, filename, file_data)
          else
            Failure(Results::Error.new(source: self.class, payload: "Unsupported upload method: #{upload_link.method}").with(code: :error))
          end
        end
      end

      private

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
        Failure(Results::Error.new(source: self.class, payload: "Failed to parse upload response: #{e.message}").with(code: :error))
      end
    end
  end
end

