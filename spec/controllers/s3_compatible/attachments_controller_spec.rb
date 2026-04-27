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

require "rails_helper"

RSpec.describe S3Compatible::AttachmentsController, type: :controller do
  let(:admin)   { create(:admin) }
  let(:user)    { create(:user) }
  let(:project) { create(:project) }
  let(:work_package) { create(:work_package, project:) }

  let!(:attachment) do
    create(:attachment,
           container:    work_package,
           author:       admin,
           digest:       "d41d8cd98f00b204e9800998ecf8427e",
           filesize:     1024,
           content_type: "application/pdf")
  end

  # The :backup_token factory backdates created_at so token.ready? returns true.
  def authorize_as(user)
    token = create(:backup_token, user:)
    request.headers["Authorization"] =
      "AWS4-HMAC-SHA256 Credential=#{token.plain_value}/20240101/us-east-1/s3/aws4_request, " \
      "SignedHeaders=host, Signature=fakesignature"
  end

  def authorize_with_bearer(user)
    token = create(:backup_token, user:)
    request.headers["Authorization"] = "Bearer #{token.plain_value}"
  end

  def expected_key
    "#{attachment.id}/#{attachment.filename}"
  end

  # ─── ListObjectsV2 ───────────────────────────────────────────────────────────

  describe "GET #list_objects" do
    subject { get :list_objects, params: { bucket: "openproject", "list-type": "2" } }

    context "as admin with AWS Sig4 auth" do
      before { authorize_as(admin) }

      it "returns 200 with XML content" do
        subject
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/xml")
      end

      it "includes bucket metadata in the response" do
        subject
        xml = Nokogiri::XML(response.body)
        expect(xml.at("ListBucketResult/Name").text).to eq("openproject")
        expect(xml.at("ListBucketResult/IsTruncated").text).to eq("false")
      end

      it "includes the attachment as a Contents element" do
        subject
        xml = Nokogiri::XML(response.body)
        keys = xml.css("Contents Key").map(&:text)
        expect(keys).to include(expected_key)
      end

      it "includes ETag and Size for each entry" do
        subject
        xml = Nokogiri::XML(response.body)
        entry = xml.at("Contents[Key='#{expected_key}']")
        expect(entry.at("ETag").text).to eq(%("#{attachment.digest}"))
        expect(entry.at("Size").text).to eq(attachment.filesize.to_s)
      end

      it "excludes quarantined attachments" do
        attachment.update_column(:status, Attachment.statuses[:quarantined])
        subject
        xml = Nokogiri::XML(response.body)
        expect(xml.css("Contents Key").map(&:text)).not_to include(expected_key)
      end

      it "excludes attachments without a digest" do
        attachment.update_column(:digest, "")
        subject
        xml = Nokogiri::XML(response.body)
        expect(xml.css("Contents Key").map(&:text)).not_to include(expected_key)
      end
    end

    context "as admin with Bearer auth" do
      before { authorize_with_bearer(admin) }

      it "returns 200" do
        subject
        expect(response).to have_http_status(:ok)
      end
    end

    context "with unknown bucket" do
      before { authorize_as(admin) }

      it "returns 404 NoSuchBucket" do
        get :list_objects, params: { bucket: "nonexistent", "list-type": "2" }
        expect(response).to have_http_status(:not_found)
        xml = Nokogiri::XML(response.body)
        expect(xml.at("Error/Code").text).to eq("NoSuchBucket")
      end
    end

    context "as non-admin user with a backup token" do
      before { authorize_as(user) }

      it "returns 403 because non-admins cannot hold backup tokens" do
        subject
        expect(response).to have_http_status(:forbidden)
        xml = Nokogiri::XML(response.body)
        expect(xml.at("Error/Code").text).to eq("AccessDenied")
      end
    end

    context "with a backup token that is not yet ready" do
      it "returns 403" do
        # Create a brand-new token (created_at = now, waiting period not elapsed)
        token = build(:backup_token, user: admin)
        token.created_at = Time.current
        token.save!
        request.headers["Authorization"] =
          "AWS4-HMAC-SHA256 Credential=#{token.plain_value}/20240101/us-east-1/s3/aws4_request, " \
          "SignedHeaders=host, Signature=fakesig"
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without any authorization header" do
      it "returns 401 with WWW-Authenticate hint" do
        subject
        expect(response).to have_http_status(:unauthorized)
        expect(response.headers["WWW-Authenticate"]).to include("AWS4-HMAC-SHA256")
      end
    end

    context "with an unrecognised token value" do
      it "returns 403" do
        request.headers["Authorization"] =
          "AWS4-HMAC-SHA256 Credential=notavalidtoken/20240101/us-east-1/s3/aws4_request, " \
          "SignedHeaders=host, Signature=fakesig"
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "pagination" do
      let!(:second_attachment) do
        create(:attachment,
               container:    work_package,
               author:       admin,
               digest:       "aabbccddeeff00112233445566778899",
               filesize:     2048,
               content_type: "text/plain")
      end

      before { authorize_as(admin) }

      it "returns only max-keys results when set to 1" do
        get :list_objects, params: { bucket: "openproject", "list-type": "2", "max-keys": "1" }
        xml = Nokogiri::XML(response.body)
        expect(xml.css("Contents").size).to eq(1)
        expect(xml.at("IsTruncated").text).to eq("true")
        expect(xml.at("NextContinuationToken")).to be_present
      end

      it "fetches the second page via continuation-token" do
        get :list_objects, params: { bucket: "openproject", "list-type": "2", "max-keys": "1" }
        token = Nokogiri::XML(response.body).at("NextContinuationToken").text

        get :list_objects, params: { bucket: "openproject", "list-type": "2",
                                     "max-keys": "1", "continuation-token": token }
        xml = Nokogiri::XML(response.body)
        expect(xml.css("Contents").size).to eq(1)
        expect(xml.at("IsTruncated").text).to eq("false")
      end

      it "returns all results when max-keys is not set" do
        get :list_objects, params: { bucket: "openproject", "list-type": "2" }
        xml = Nokogiri::XML(response.body)
        expect(xml.css("Contents").size).to be >= 2
        expect(xml.at("IsTruncated").text).to eq("false")
      end
    end
  end

  # ─── HeadObject ──────────────────────────────────────────────────────────────

  describe "HEAD #head_object" do
    let(:key) { expected_key }

    before { authorize_as(admin) }

    context "with a valid key" do
      it "returns 200" do
        head :head_object, params: { bucket: "openproject", key: }
        expect(response).to have_http_status(:ok)
      end

      it "sets ETag header to the attachment digest" do
        head :head_object, params: { bucket: "openproject", key: }
        expect(response.headers["ETag"]).to eq(%("#{attachment.digest}"))
      end

      it "sets Content-Length header" do
        head :head_object, params: { bucket: "openproject", key: }
        expect(response.headers["Content-Length"]).to eq(attachment.filesize.to_s)
      end

      it "sets Last-Modified header" do
        head :head_object, params: { bucket: "openproject", key: }
        expect(response.headers["Last-Modified"]).to be_present
      end
    end

    context "with a non-existent key" do
      it "returns 404" do
        head :head_object, params: { bucket: "openproject", key: "99999/missing.pdf" }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ─── GetObject ───────────────────────────────────────────────────────────────

  describe "GET #get_object" do
    let(:key) { expected_key }

    before { authorize_as(admin) }

    context "with local storage" do
      let(:tmpfile) do
        Tempfile.new(["attachment", ".pdf"]).tap do |f|
          f.write("file content")
          f.flush
        end
      end

      before do
        allow_any_instance_of(Attachment).to receive(:external_storage?).and_return(false)
        allow_any_instance_of(Attachment).to receive(:diskfile).and_return(double(path: tmpfile.path))
      end

      after { tmpfile.unlink }

      it "returns 200 and sends the file" do
        get :get_object, params: { bucket: "openproject", key: }
        expect(response).to have_http_status(:ok)
      end

      it "sets the ETag header" do
        get :get_object, params: { bucket: "openproject", key: }
        expect(response.headers["ETag"]).to eq(%("#{attachment.digest}"))
      end
    end

    context "with external (fog) storage" do
      let(:external_url) { URI.parse("https://s3.example.com/bucket/object?signed=1") }

      before do
        allow_any_instance_of(Attachment).to receive(:external_storage?).and_return(true)
        allow_any_instance_of(Attachment).to receive(:external_url).and_return(external_url)
      end

      it "redirects to the external URL" do
        get :get_object, params: { bucket: "openproject", key: }
        expect(response).to have_http_status(:found)
        expect(response.headers["Location"]).to eq(external_url.to_s)
      end
    end

    context "with a non-existent key" do
      it "returns 404" do
        get :get_object, params: { bucket: "openproject", key: "99999/missing.pdf" }
        expect(response).to have_http_status(:not_found)
        xml = Nokogiri::XML(response.body)
        expect(xml.at("Error/Code").text).to eq("NoSuchKey")
      end
    end
  end
end
