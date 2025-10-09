# frozen_string_literal: true

# -- copyright
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
# ++

require "spec_helper"

RSpec.shared_examples_for "has workspace linked" do
  let(:link) { :project }
  let(:title) { workspace.name }

  context "for a project" do
    it_behaves_like "has a titled link" do
      let(:href) { api_v3_paths.project workspace.id }
    end
  end

  context "for a program" do
    let(:workspace) { build_stubbed(:program) }

    it_behaves_like "has a titled link" do
      let(:href) { api_v3_paths.program workspace.id }
    end
  end

  context "for a portfolio" do
    let(:workspace) { build_stubbed(:portfolio) }

    it_behaves_like "has a titled link" do
      let(:href) { api_v3_paths.portfolio workspace.id }
    end
  end
end

RSpec.shared_examples_for "has workspace embedded" do
  let(:embedded_path) { "_embedded/project" }
  let(:embedded_resource) { workspace }
  let(:embedded_resource_type) { "Project" }

  before do
    allow(workspace)
      .to receive(:visible?)
            .and_return(true)
  end

  context "for a project" do
    let(:embedded_resource_type) { "Project" }

    it_behaves_like "has the resource embedded"
  end

  context "for a program" do
    let(:workspace) { build_stubbed(:program) }
    let(:embedded_resource_type) { "Program" }

    it_behaves_like "has the resource embedded"
  end

  context "for a portfolio" do
    let(:workspace) { build_stubbed(:portfolio) }
    let(:embedded_resource_type) { "Portfolio" }

    it_behaves_like "has the resource embedded"
  end
end
