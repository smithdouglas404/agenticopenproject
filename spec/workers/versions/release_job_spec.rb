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

RSpec.describe Versions::ReleaseJob do
  shared_let(:user) { create(:admin) }
  shared_let(:project) { create(:project) }
  shared_let(:release) { create(:version, project:, kind: "release") }

  it "releases the version via Versions::ReleaseService" do
    described_class.perform_now(version_id: release.id, user_id: user.id, strategy: "force")

    expect(release.reload.status).to eq("closed")
  end

  it "does nothing when the version no longer exists" do
    expect do
      described_class.perform_now(version_id: -1, user_id: user.id, strategy: "force")
    end.not_to raise_error
  end

  it "logs (and does not raise) when the release can no longer be performed" do
    release.update!(status: "closed") # no longer open, so the service rejects it

    allow(Rails.logger).to receive(:error)
    expect do
      described_class.perform_now(version_id: release.id, user_id: user.id, strategy: "force")
    end.not_to raise_error
    expect(Rails.logger).to have_received(:error).with(/ReleaseJob/)
  end
end
