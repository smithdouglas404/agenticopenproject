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

module S3Compatible
  # Read-only S3-compatible endpoint for bulk attachment export.
  #
  # Implements the minimal S3 surface needed by `aws s3 sync` and rclone:
  #   ListObjectsV2  GET  /s3/:bucket?list-type=2
  #   GetObject      GET  /s3/:bucket/*key
  #   HeadObject     HEAD /s3/:bucket/*key
  #
  # Authentication: supply your OpenProject backup token as the AWS access key ID.
  # Using the backup token ties this endpoint to the same audit trail as the existing
  # backup feature — every token reset notifies the user and all administrators.
  # The Signature V4 HMAC is accepted by the AWS SDK but not verified server-side.
  #
  # The endpoint is only available when backups are enabled in the OpenProject
  # configuration and after the backup token's initial waiting period has elapsed.
  #
  # Object keys have the form "{attachment_id}/{filename}", which is stable across
  # renames and moves. ETags are the stored MD5 digest, so `sync` only downloads
  # files that have actually changed.
  class AttachmentsController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :user_setup
    skip_before_action :check_if_login_required

    no_authorization_required! :list_objects, :get_object, :head_object

    before_action :authenticate_s3_request

    BUCKET_NAME = "openproject"
    MAX_KEYS    = 1000

    # GET /s3/:bucket?list-type=2[&max-keys=N][&continuation-token=T]
    def list_objects
      unless params[:bucket] == BUCKET_NAME
        return render_s3_error(:not_found, "NoSuchBucket", "The specified bucket does not exist.")
      end

      raw_max  = params[:"max-keys"].to_i
      max_keys = raw_max.positive? ? [raw_max, MAX_KEYS].min : MAX_KEYS
      after_id = params[:"continuation-token"] ? decode_token(params[:"continuation-token"]) : nil

      scope = listable_attachments
      scope = scope.where("attachments.id > ?", after_id) if after_id

      batch     = scope.order(:id).limit(max_keys + 1).to_a
      truncated = batch.size > max_keys
      results   = batch.first(max_keys)
      next_token = truncated ? encode_token(results.last.id) : nil

      render body: list_objects_xml(results, max_keys, truncated, next_token),
             content_type: "application/xml"
    end

    # GET /s3/:bucket/*key
    def get_object
      attachment = find_attachment
      return render_s3_error(:not_found, "NoSuchKey", "The specified key does not exist.") unless attachment

      set_object_headers(attachment)

      if attachment.external_storage?
        redirect_to attachment.external_url.to_s, allow_other_host: true, status: :found
      else
        send_file attachment.diskfile.path,
                  type:        "application/octet-stream",
                  disposition: :attachment,
                  filename:    attachment.filename
      end
    end

    # HEAD /s3/:bucket/*key
    def head_object
      attachment = find_attachment
      return render_s3_error(:not_found, "NoSuchKey", "The specified key does not exist.") unless attachment

      set_object_headers(attachment)
      head :ok
    end

    private

    def authenticate_s3_request
      unless OpenProject::Configuration.backup_enabled?
        return render_s3_error(:forbidden, "AccessDenied", "Backups are not enabled on this instance.")
      end

      raw_token = extract_token_value
      unless raw_token
        response.headers["WWW-Authenticate"] = "AWS4-HMAC-SHA256"
        return render_s3_error(:unauthorized, "InvalidAccessKeyId",
                               "No backup token found. Supply your OpenProject backup token as the AWS access key ID.")
      end

      backup_token = Token::Backup.find_by_plaintext_value(raw_token)

      unless backup_token&.user&.active? && backup_token.user.admin?
        return render_s3_error(:forbidden, "AccessDenied", "Access Denied")
      end

      unless backup_token.ready?
        hours = (OpenProject::Configuration.backup_initial_waiting_period / 1.hour).ceil
        return render_s3_error(:forbidden, "AccessDenied",
                               I18n.t("backup.error.token_cooldown", hours:))
      end

      User.current = backup_token.user
    end

    # Extracts the raw token value from the Authorization header.
    #
    # Supported formats:
    #   AWS Signature V4:  Authorization: AWS4-HMAC-SHA256 Credential=<token>/...
    #   Bearer token:      Authorization: Bearer <token>
    #   HTTP Basic:        Authorization: Basic base64(anything:<token>)
    #
    # For AWS Signature V4 the HMAC signature is accepted by the AWS SDK but not
    # verified here; only the credential (i.e. the OpenProject backup token) is used.
    def extract_token_value
      auth = request.headers["Authorization"].to_s

      if (m = auth.match(/\AAWS4-HMAC-SHA256\s+Credential=([^\/,\s]+)/))
        return m[1]
      end

      if (m = auth.match(/\ABearer\s+(\S+)/i))
        return m[1]
      end

      if (creds = ActionController::HttpAuthentication::Basic.user_name_and_password(request))
        _username, password = creds
        return password.presence
      end

      nil
    end

    # Returns attachments eligible for export:
    #   - fully uploaded or virus-scanned
    #   - not internal (Export containers)
    #   - have a computed digest (needed as ETag)
    def listable_attachments
      Attachment
        .where(status: [Attachment.statuses[:uploaded], Attachment.statuses[:scanned]])
        .where.not(container_type: "Export")
        .where.not(digest: [nil, ""])
    end

    def find_attachment
      id_str = params[:key].to_s.split("/", 2).first
      return nil unless id_str =~ /\A\d+\z/

      listable_attachments.find_by(id: id_str.to_i)
    end

    def object_key(attachment)
      "#{attachment.id}/#{attachment.filename}"
    end

    def set_object_headers(attachment)
      response.headers["ETag"]             = %("#{attachment.digest}")
      response.headers["Content-Length"]   = attachment.filesize.to_s
      response.headers["Content-Type"]     = "application/octet-stream"
      response.headers["Last-Modified"]    = attachment.updated_at.httpdate
      response.headers["Accept-Ranges"]    = "bytes"
      response.headers["x-amz-request-id"] = SecureRandom.hex(8)
    end

    def list_objects_xml(attachments, max_keys, truncated, next_token)
      Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml.ListBucketResult(xmlns: "http://s3.amazonaws.com/doc/2006-03-01/") do
          xml.Name   BUCKET_NAME
          xml.Prefix ""
          xml.MaxKeys max_keys
          xml.IsTruncated truncated
          xml.NextContinuationToken next_token if next_token

          attachments.each do |a|
            xml.Contents do
              xml.Key         object_key(a)
              xml.LastModified a.updated_at.iso8601(3)
              xml.ETag        %("#{a.digest}")
              xml.Size        a.filesize
              xml.StorageClass "STANDARD"
            end
          end
        end
      end.to_xml
    end

    def render_s3_error(status, code, message)
      xml = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml.Error do
          xml.Code      code
          xml.Message   message
          xml.RequestId SecureRandom.hex(8)
        end
      end.to_xml

      render status:, body: xml, content_type: "application/xml"
    end

    # Cursor-based pagination tokens are Base64-encoded attachment IDs.
    def encode_token(id)
      Base64.urlsafe_encode64(id.to_s)
    end

    def decode_token(token)
      Integer(Base64.urlsafe_decode64(token))
    rescue ArgumentError, TypeError
      nil
    end
  end
end
