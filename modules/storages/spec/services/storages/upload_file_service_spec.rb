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

module Storages
  FakeProject = Data.define(:id, :name)

  class TestIdentifier < Adapters::Providers::Nextcloud::ManagedFolderIdentifier
    def initialize(project_storage)
      super
      @project = FakeProject.new(-273, project_storage.project.name)
    end
  end

  RSpec.describe UploadFileService, :webmock, type: :model do
    before do
      Adapters::Registry.stub("nextcloud.models.managed_folder_identifier", TestIdentifier)
    end

    let(:user) { create(:admin) }
    let(:project) { create(:project, name: "UploadProject") }
    let(:storage) { create(:nextcloud_storage_with_local_connection) }
    let(:project_storage) { create(:project_storage, project:, storage:, project_folder_id: "/project_folder") }
    let(:work_package) { create(:work_package, project:, author: user) }
    let(:file_path) { "/uploads/documents" }
    let(:filename) { "test_file.pdf" }
    let(:file_data) { StringIO.new("This is the file content.") }

    let(:auth_strategy) { Storages::Adapters::Registry["nextcloud.authentication.userless"].call }
    let(:parent_folder) do
      Storages::Adapters::Results::StorageFile.new(
        id: "123",
        name: "documents",
        mime_type: "application/x-op-directory",
        location: "/project_folder/uploads/documents",
        permissions: %i[readable writeable]
      )
    end
    let(:file_collection) do
      Storages::Adapters::Results::StorageFileCollection.new(
        files: [],
        parent: parent_folder,
        ancestors: []
      )
    end
    let(:uploaded_file) do
      Storages::Adapters::Results::StorageFile.new(
        id: "456",
        name: filename,
        mime_type: "application/pdf",
        size: 100,
        location: "/project_folder/uploads/documents/#{filename}",
        permissions: %i[readable writeable]
      )
    end

    describe ".call" do
      subject(:result) do
        described_class.call(container: work_package, project_storage:, file_path:, filename:, file_data:)
      end

      context "when storage is not Nextcloud" do
        let(:storage) { create(:one_drive_storage) }

        it "returns failure with unsupported_storage_type error" do
          expect(result).to be_failure
          expect(result.errors[:base]).not_to be_empty
        end

        it "does not create a FileLink" do
          expect { result }.not_to change(Storages::FileLink, :count)
        end
      end

      context "when storage is Nextcloud" do
        context "when folder exists", vcr: "services/nextcloud_upload_file_success_file" do
          # ...existing code...

          it "uploads and creates a FileLink via Nextcloud" do
            expect do
              described_class.call(container: work_package, project_storage: project_storage, file_path: file_path,
                                   filename: filename, file_data: file_data)
            end.to change(FileLink, :count).by(1)
            file_link = FileLink.last
            expect(file_link.creator).to eq(user)
            expect(file_link.origin_name).to eq(filename)
          end
        end

        context "when folder does not exist" do
          # ...existing code...
          it "creates the folder, uploads, and creates a FileLink",
             vcr: "services/nextcloud_upload_file_new_folder_success_file" do
            expect do
              described_class.call(container: work_package, project_storage: project_storage,
                                   file_path: "/uploads/documents/secret", filename: filename, file_data: file_data)
            end.to change(FileLink, :count).by(1)
            file_link = FileLink.last
            expect(file_link.creator).to eq(user)
            expect(file_link.origin_name).to eq(filename)
          end
        end

        context "when folder creation fails" do
          before do
            create_folder_command = double("create_folder_command")
            allow(Storages::Adapters::Registry).to receive(:[]).with("#{storage}.commands.create_folder").and_return(create_folder_command)
            allow(create_folder_command).to receive(:call).and_return(
              Failure(Storages::Adapters::Results::Error.new(source: self.class).with(code: :error))
            )
          end

          it "returns failure" do
            expect(result).to be_failure
          end

          it "does not create a FileLink" do
            expect { result }.not_to change(Storages::FileLink, :count)
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
          files_query = double("files_query")
          allow(Storages::Adapters::Registry).to receive(:resolve).with("#{storage}.queries.files").and_return(files_query)
          allow(files_query).to receive(:call).and_return(Success(file_collection))

          upload_command = double("upload_command")
          allow(Storages::Adapters::Registry).to receive(:[]).with("nextcloud.commands.upload_file").and_return(upload_command)
          allow(upload_command).to receive(:call).and_return(Success(uploaded_file))

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

      context "when container is not a WorkPackage" do
        let(:container) { create(:project) }

        subject(:result) do
          described_class.call(
            container:,
            project_storage:,
            file_path:,
            filename:,
            file_data:
          )
        end

        before do
          files_query = double("files_query")
          allow(Storages::Adapters::Registry).to receive(:resolve).with("#{storage}.queries.files").and_return(files_query)
          allow(files_query).to receive(:call).and_return(Success(file_collection))

          upload_command = double("upload_command")
          allow(Storages::Adapters::Registry).to receive(:[]).with("nextcloud.commands.upload_file").and_return(upload_command)
          allow(upload_command).to receive(:call).and_return(Success(uploaded_file))

          allow(Storages::FileLinks::CreateService).to receive(:new).and_return(
            double(call: ServiceResult.success(result: create(:file_link, container:, storage:)))
          )
        end

        it "uses User.system as creator" do
          result
          file_link = Storages::FileLink.last
          expect(file_link.creator).to eq(User.system)
        end
      end

      context "when file upload fails" do
        before do
          files_query = double("files_query")
          allow(Storages::Adapters::Registry).to receive(:resolve).with("#{storage}.queries.files").and_return(files_query)
          allow(files_query).to receive(:call).and_return(Success(file_collection))

          upload_command = double("upload_command")
          allow(Storages::Adapters::Registry).to receive(:[]).with("nextcloud.commands.upload_file").and_return(upload_command)
          allow(upload_command).to receive(:call).and_return(
            Failure(Storages::Adapters::Results::Error.new(source: Storages::UploadFileService,
                                                           payload: "Upload failed").with(code: :error))
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
          files_query = double("files_query")
          allow(Storages::Adapters::Registry).to receive(:resolve).with("#{storage}.queries.files").and_return(files_query)
          allow(files_query).to receive(:call).and_return(Success(file_collection))

          upload_command = double("upload_command")
          allow(Storages::Adapters::Registry).to receive(:[]).with("nextcloud.commands.upload_file").and_return(upload_command)
          allow(upload_command).to receive(:call).and_return(Success(uploaded_file))

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

      context "with file path that doesn't start with /" do
        let(:file_path) { "uploads/documents" }
        let(:files_query) { double("files_query") }

        before do
          allow(Storages::Adapters::Registry).to receive(:resolve).with("#{storage}.queries.files").and_return(files_query)
          allow(files_query).to receive(:call).and_return(Success(file_collection))

          upload_command = double("upload_command")
          allow(Storages::Adapters::Registry).to receive(:[]).with("nextcloud.commands.upload_file").and_return(upload_command)
          allow(upload_command).to receive(:call).and_return(Success(uploaded_file))

          allow(Storages::FileLinks::CreateService).to receive(:new).and_return(
            double(call: ServiceResult.success(result: create(:file_link, container: work_package, storage:)))
          )
        end

        it "normalizes the path by removing leading slash when combining" do
          expect(files_query).to receive(:call).with(
            hash_including(
              auth_strategy:,
              storage:,
              input_data: anything
            )
          ).and_return(Success(file_collection))
          result
        end
      end

      context "with nested folder path" do
        let(:file_path) { "/uploads/documents/2024" }
        let(:created_folder) do
          Storages::Adapters::Results::StorageFileInfo.new(
            status: "OK",
            status_code: 200,
            id: "999",
            name: "2024",
            location: "/project_folder/uploads/documents/2024"
          )
        end

        before do
          files_query = double("files_query")
          allow(Storages::Adapters::Registry).to receive(:resolve).with("#{storage}.queries.files").and_return(files_query)
          allow(files_query).to receive(:call).and_return(
            Failure(Storages::Adapters::Results::Error.new(source: self.class).with(code: :not_found))
          )

          create_folder_command = double("create_folder_command")
          allow(Storages::Adapters::Registry).to receive(:[]).with("#{storage}.commands.create_folder").and_return(create_folder_command)
          allow(create_folder_command).to receive(:call).and_return(Success(created_folder))

          upload_command = double("upload_command")
          allow(Storages::Adapters::Registry).to receive(:[]).with("nextcloud.commands.upload_file").and_return(upload_command)
          allow(upload_command).to receive(:call).and_return(Success(uploaded_file))

          allow(Storages::FileLinks::CreateService).to receive(:new).and_return(
            double(call: ServiceResult.success(result: create(:file_link, container: work_package, storage:)))
          )
        end

        it "creates the folder" do
          create_folder_command = double("create_folder_command")
          allow(Storages::Adapters::Registry).to receive(:[]).with("#{storage}.commands.create_folder").and_return(create_folder_command)
          expect(create_folder_command).to receive(:call).and_return(Success(created_folder))
          result
        end
      end

      context "when project_folder_id is nil" do
        let(:project_storage) { create(:project_storage, project:, storage:, project_folder_id: nil) }

        let(:files_query) { double("files_query") }

        before do
          allow(Storages::Adapters::Registry).to receive(:resolve).with("#{storage}.queries.files").and_return(files_query)
          allow(files_query).to receive(:call).and_return(Success(file_collection))

          upload_command = double("upload_command")
          allow(Storages::Adapters::Registry).to receive(:[]).with("nextcloud.commands.upload_file").and_return(upload_command)
          allow(upload_command).to receive(:call).and_return(Success(uploaded_file))

          allow(Storages::FileLinks::CreateService).to receive(:new).and_return(
            double(call: ServiceResult.success(result: create(:file_link, container: work_package, storage:)))
          )
        end

        it "uses managed_project_folder_path as prefix" do
          expect(files_query).to receive(:call).with(
            hash_including(
              auth_strategy:,
              storage:,
              input_data: anything
            )
          ).and_return(Success(file_collection))
          result
        end
      end

      context "when project_folder_id is empty string" do
        let(:project_storage) { create(:project_storage, project:, storage:, project_folder_id: "") }

        before do
          files_query = double("files_query")
          allow(Storages::Adapters::Registry).to receive(:resolve).with("#{storage}.queries.files").and_return(files_query)
          allow(files_query).to receive(:call).and_return(Success(file_collection))

          upload_command = double("upload_command")
          allow(Storages::Adapters::Registry).to receive(:[]).with("nextcloud.commands.upload_file").and_return(upload_command)
          allow(upload_command).to receive(:call).and_return(Success(uploaded_file))

          allow(Storages::FileLinks::CreateService).to receive(:new).and_return(
            double(call: ServiceResult.success(result: create(:file_link, container: work_package, storage:)))
          )
        end

        it "uses managed_project_folder_path as prefix" do
          expect(files_query).to receive(:call).with(
            hash_including(
              auth_strategy:,
              storage:,
              input_data: anything
            )
          ).and_return(Success(file_collection))
          result
        end
      end
    end
  end
end
