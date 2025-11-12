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

RSpec.describe Documents::SetAttributesService do
  shared_let(:user) { create(:admin) }
  shared_let(:project) { create(:project) }
  shared_let(:experimental_type) { create(:document_type, :experimental) }

  current_user { user }

  subject(:set_attributes_service) do
    described_class.new(
      user:,
      model: Document.new,
      contract_class: Documents::BaseContract
    ).call(type_id: experimental_type.id, title: "A Document", project:)
  end

  describe "#call" do
    context "with 'Experimental' document type" do
      context "and block note editor feature active", with_flag: { block_note_editor: true } do
        it "sets the document kind to 'collaborative'" do
          expect(set_attributes_service).to be_success
          expect(set_attributes_service.result).to be_collaborative
        end
      end

      context "and block note editor feature inactive", with_flag: { block_note_editor: false } do
        it "sets the document kind to 'classic'" do
          expect(set_attributes_service).to be_success
          expect(set_attributes_service.result).to be_classic
        end
      end
    end
  end
end
