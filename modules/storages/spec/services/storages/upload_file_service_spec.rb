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
          expect { result }.not_to change(FileLink, :count)
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
      end
    end
  end
end
