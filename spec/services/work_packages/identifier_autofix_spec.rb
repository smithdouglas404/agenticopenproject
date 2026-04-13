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

RSpec.describe WorkPackages::IdentifierAutofix do
  describe ".job_in_progress?" do
    subject { described_class.job_in_progress? }

    context "when no conversion jobs exist" do
      it { is_expected.to be false }
    end

    context "when a ConvertInstanceToSemanticIdsJob job is running (finished_at: nil)" do
      before do
        GoodJob::Job.create!(
          job_class: ProjectIdentifiers::ConvertInstanceToSemanticIdsJob.name,
          serialized_params: { "job_class" => ProjectIdentifiers::ConvertInstanceToSemanticIdsJob.name },
          finished_at: nil
        )
      end

      it { is_expected.to be true }
    end

    context "when a BackfillProjectJob is running (finished_at: nil)" do
      before do
        GoodJob::Job.create!(
          job_class: ProjectIdentifiers::ConvertProjectToSemanticIdsJob.name,
          serialized_params: { "job_class" => ProjectIdentifiers::ConvertProjectToSemanticIdsJob.name },
          finished_at: nil
        )
      end

      it { is_expected.to be true }
    end

    context "when all conversion jobs have finished" do
      before do
        GoodJob::Job.create!(
          job_class: ProjectIdentifiers::ConvertInstanceToSemanticIdsJob.name,
          serialized_params: { "job_class" => ProjectIdentifiers::ConvertInstanceToSemanticIdsJob.name },
          finished_at: 1.minute.ago
        )
        GoodJob::Job.create!(
          job_class: ProjectIdentifiers::ConvertProjectToSemanticIdsJob.name,
          serialized_params: { "job_class" => ProjectIdentifiers::ConvertProjectToSemanticIdsJob.name },
          finished_at: 1.minute.ago
        )
      end

      it { is_expected.to be false }
    end
  end
end
