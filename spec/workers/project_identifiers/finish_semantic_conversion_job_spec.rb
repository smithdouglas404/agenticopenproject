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

RSpec.describe ProjectIdentifiers::FinishSemanticConversionJob do
  subject(:job) { described_class.new }

  let(:finder) { instance_double(ProjectIdentifiers::PendingProjectsFinder) }

  before do
    allow(ProjectIdentifiers::PendingProjectsFinder).to receive(:new).and_return(finder)
    allow(Setting::WorkPackageIdentifier).to receive(:enable_semantic!)
  end

  describe "#perform" do
    context "when no projects remain" do
      before { allow(finder).to receive(:project_ids).and_return(Set.new) }

      it "enables semantic mode" do
        job.perform
        expect(Setting::WorkPackageIdentifier).to have_received(:enable_semantic!)
      end

      it "does not re-run the conversion job" do
        allow(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).to receive(:new)
        job.perform
        expect(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).not_to have_received(:new)
      end
    end

    context "when projects still remain" do
      before { allow(finder).to receive(:project_ids).and_return(Set[1]) }

      it "synchronously re-runs ConvertInstanceToSemanticIdsJob before enabling semantic" do
        convert_job = instance_double(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob)
        allow(ProjectIdentifiers::ConvertInstanceToSemanticIdsJob).to receive(:new).and_return(convert_job)
        allow(convert_job).to receive(:perform)

        job.perform

        expect(convert_job).to have_received(:perform)
        expect(Setting::WorkPackageIdentifier).to have_received(:enable_semantic!)
      end
    end
  end
end
