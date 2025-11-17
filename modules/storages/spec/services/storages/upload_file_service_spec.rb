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

require "spec_helper"
require_module_spec_helper

RSpec.describe Storages::UploadFileService, type: :model do
  let(:user) { create(:admin) }
  let(:project) { create(:project) }
  let(:storage) { create(:storage, provider_type: "Storages::NextcloudStorage") }
  let(:project_storage) { create(:project_storage, project:, storage:, project_folder_id: "/project_folder") }
  let(:work_package) { create(:work_package, project:, author: user) }
  let(:file_path) { "/uploads/documents" }
  let(:filename) { "test_file.pdf" }
  let(:file_data) { StringIO.new("test file content") }

  let(:service) { described_class.new(project_storage) }

  describe ".call" do
    subject(:result) do
      described_class.call(
        container: work_package,
        project_storage:,
        file_path:,
        filename:,
        file_data:
      )
    end

    context "when folder exists" do
      before do
        allow(Storages::StorageFilesService).to receive(:call).and_return(
          ServiceResult.success(result: [])
        )
      end

      context "with successful upload and file link creation" do
        let(:upload_link) do
          Storages::Adapters::Results::UploadLink.build(
            destination: "https://example.com/upload/token123",
            method: :post
          ).value!
        end

        before do
          allow(Storages::UploadLinkService).to receive(:call).and_return(
            ServiceResult.success(result: upload_link)
          )

          allow(Storages::Files::UploadService).to receive(:call).and_return(
            Success({
              id: "123",
              name: filename,
              mime_type: "application/pdf",
              size: 100
            })
          )

          allow(Storages::FileLinks::CreateService).to receive(:new).and_return(
            double(call: ServiceResult.success(result: create(:file_link, container: work_package, storage:)))
          )
        end

        it "returns success" do
          expect(result).to be_success
        end

        it "creates a FileLink" do
          expect { result }.to change(Storages::FileLink, :count).by(1)
        end

        it "uses the work package author as creator" do
          result
          file_link = Storages::FileLink.last
          expect(file_link.creator).to eq(user)
        end
      end
    end

    context "when folder does not exist" do
      before do
        allow(Storages::StorageFilesService).to receive(:call).and_return(
          ServiceResult.failure(errors: ActiveModel::Errors.new(double))
        )

        created_folder = Storages::Adapters::Results::StorageFileInfo.build(
          status: "OK",
          status_code: 200,
          id: "/uploads/documents",
          name: "documents",
          location: "/uploads/documents"
        ).value!

        allow(Storages::CreateFolderService).to receive(:call).and_return(
          ServiceResult.success(result: created_folder)
        )
      end

      context "with successful folder creation, upload and file link creation" do
        let(:upload_link) do
          Storages::Adapters::Results::UploadLink.build(
            destination: "https://example.com/upload/token123",
            method: :post
          ).value!
        end

        before do
          allow(Storages::UploadLinkService).to receive(:call).and_return(
            ServiceResult.success(result: upload_link)
          )

          allow(Storages::Files::UploadService).to receive(:call).and_return(
            Success({
              id: "123",
              name: filename,
              mime_type: "application/pdf",
              size: 100
            })
          )

          allow(Storages::FileLinks::CreateService).to receive(:new).and_return(
            double(call: ServiceResult.success(result: create(:file_link, container: work_package, storage:)))
          )
        end

        it "creates the folder structure" do
          expect(Storages::CreateFolderService).to receive(:call).at_least(:once)
          result
        end

        it "returns success" do
          expect(result).to be_success
        end

        it "creates a FileLink" do
          expect { result }.to change(Storages::FileLink, :count).by(1)
        end
      end
    end

    context "when work package has no author" do
      let(:work_package_without_author) { create(:work_package, project:, author: nil) }

      subject(:result) do
        described_class.call(
          container: work_package_without_author,
          project_storage:,
          file_path:,
          filename:,
          file_data:
        )
      end

      before do
        allow(Storages::StorageFilesService).to receive(:call).and_return(
          ServiceResult.success(result: [])
        )

        upload_link = Storages::Adapters::Results::UploadLink.build(
          destination: "https://example.com/upload/token123",
          method: :post
        ).value!

        allow(Storages::UploadLinkService).to receive(:call).and_return(
          ServiceResult.success(result: upload_link)
        )

        allow(Storages::Files::UploadService).to receive(:call).and_return(
          Success({
            id: "123",
            name: filename,
            mime_type: "application/pdf",
            size: 100
          })
        )

        allow(Storages::FileLinks::CreateService).to receive(:new).and_return(
          double(call: ServiceResult.success(result: create(:file_link, container: work_package_without_author, storage:)))
        )
      end

      it "uses User.system as creator" do
        result
        file_link = Storages::FileLink.last
        expect(file_link.creator).to eq(User.system)
      end
    end

    context "when upload link service fails" do
      before do
        allow(Storages::StorageFilesService).to receive(:call).and_return(
          ServiceResult.success(result: [])
        )

        allow(Storages::UploadLinkService).to receive(:call).and_return(
          ServiceResult.failure(errors: ActiveModel::Errors.new(double).tap { |e| e.add(:base, :error) })
        )
      end

      it "returns failure" do
        expect(result).to be_failure
      end

      it "does not create a FileLink" do
        expect { result }.not_to change(Storages::FileLink, :count)
      end
    end

    context "when file upload fails" do
      before do
        allow(Storages::StorageFilesService).to receive(:call).and_return(
          ServiceResult.success(result: [])
        )

        upload_link = Storages::Adapters::Results::UploadLink.build(
          destination: "https://example.com/upload/token123",
          method: :post
        ).value!

        allow(Storages::UploadLinkService).to receive(:call).and_return(
          ServiceResult.success(result: upload_link)
        )

        allow(Storages::Files::UploadService).to receive(:call).and_return(
          Failure(Storages::Adapters::Results::Error.new(source: Storages::Files::UploadService, payload: "Upload failed").with(code: :error))
        )
      end

      it "returns failure" do
        expect(result).to be_failure
      end

      it "does not create a FileLink" do
        expect { result }.not_to change(Storages::FileLink, :count)
      end
    end

    context "when FileLink creation fails" do
      before do
        allow(Storages::StorageFilesService).to receive(:call).and_return(
          ServiceResult.success(result: [])
        )

        upload_link = Storages::Adapters::Results::UploadLink.build(
          destination: "https://example.com/upload/token123",
          method: :post
        ).value!

        allow(Storages::UploadLinkService).to receive(:call).and_return(
          ServiceResult.success(result: upload_link)
        )

        allow(Storages::Files::UploadService).to receive(:call).and_return(
          Success({
            id: "123",
            name: filename,
            mime_type: "application/pdf",
            size: 100
          })
        )

        allow(Storages::FileLinks::CreateService).to receive(:new).and_return(
          double(call: ServiceResult.failure(errors: ActiveModel::Errors.new(double).tap { |e| e.add(:base, :error) }))
        )
      end

      it "returns failure" do
        expect(result).to be_failure
      end

      it "does not create a FileLink" do
        expect { result }.not_to change(Storages::FileLink, :count)
      end
    end

    context "with PUT upload method (OneDrive/SharePoint)" do
      let(:storage) { create(:storage, provider_type: "Storages::OneDriveStorage") }
      let(:project_storage) { create(:project_storage, project:, storage:, project_folder_id: "drive_id:folder_id") }

      before do
        allow(Storages::StorageFilesService).to receive(:call).and_return(
          ServiceResult.success(result: [])
        )

        upload_link = Storages::Adapters::Results::UploadLink.build(
          destination: "https://graph.microsoft.com/v1.0/upload/session123",
          method: :put
        ).value!

        allow(Storages::UploadLinkService).to receive(:call).and_return(
          ServiceResult.success(result: upload_link)
        )

        allow(Storages::Files::UploadService).to receive(:call).and_return(
          Success({
            id: "file123",
            name: filename,
            mime_type: "application/pdf",
            size: 100
          })
        )

        allow(Storages::FileLinks::CreateService).to receive(:new).and_return(
          double(call: ServiceResult.success(result: create(:file_link, container: work_package, storage:)))
        )
      end

      it "uses PUT method for upload" do
        expect(Storages::Files::UploadService).to receive(:call).with(
          hash_including(upload_link: upload_link, filename:, file_data:, storage:)
        )
        result
      end
    end

    context "with nested folder path" do
      let(:file_path) { "/uploads/documents/2024" }

      before do
        # First check fails (folder doesn't exist)
        allow(Storages::StorageFilesService).to receive(:call).and_return(
          ServiceResult.failure(errors: ActiveModel::Errors.new(double))
        )

        # Create folder service will be called for each folder component
        created_folder = Storages::Adapters::Results::StorageFileInfo.build(
          status: "OK",
          status_code: 200,
          id: "/uploads/documents/2024",
          name: "2024",
          location: "/uploads/documents/2024"
        ).value!

        allow(Storages::CreateFolderService).to receive(:call).and_return(
          ServiceResult.success(result: created_folder)
        )

        upload_link = Storages::Adapters::Results::UploadLink.build(
          destination: "https://example.com/upload/token123",
          method: :post
        ).value!

        allow(Storages::UploadLinkService).to receive(:call).and_return(
          ServiceResult.success(result: upload_link)
        )

        allow(Storages::Files::UploadService).to receive(:call).and_return(
          Success({
            id: "123",
            name: filename,
            mime_type: "application/pdf",
            size: 100
          })
        )

        allow(Storages::FileLinks::CreateService).to receive(:new).and_return(
          double(call: ServiceResult.success(result: create(:file_link, container: work_package, storage:)))
        )
      end

      it "creates nested folder structure" do
        expect(Storages::CreateFolderService).to receive(:call).at_least(:once)
        result
      end
    end
  end
end

