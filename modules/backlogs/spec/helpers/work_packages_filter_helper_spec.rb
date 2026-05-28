# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"

RSpec.describe WorkPackagesFilterHelper do
  let(:project) { create(:project) }
  let(:version) { create(:version, project:) }

  def query_props_from(path)
    path_regexp = Regexp.new("^#{project_work_packages_path(project.identifier)}\\?query_props=(.*)")
    match = path.match(path_regexp)
    expect(match).not_to be_nil
    JSON.parse(CGI.unescape(match[1])).with_indifferent_access
  end

  context "when the project has no Done statuses configured" do
    let!(:closed_status) { create(:status, is_closed: true) }
    let!(:open_status)   { create(:status, is_closed: false) }

    it "still uses the generic 'c' status meta-filter for the closed link" do
      props = query_props_from(helper.project_work_packages_closed_version_path(version))
      status_filter = props[:f].find { |f| f[:n] == "status" }
      expect(status_filter[:o]).to eq "c"
      expect(status_filter[:v]).to be_nil
    end

    it "still uses the generic 'o' status meta-filter for the open link" do
      props = query_props_from(helper.project_work_packages_open_version_path(version))
      status_filter = props[:f].find { |f| f[:n] == "status" }
      expect(status_filter[:o]).to eq "o"
      expect(status_filter[:v]).to be_nil
    end
  end

  context "when the project has Done statuses configured" do
    let!(:closed_status) { create(:status, is_closed: true) }
    let!(:open_status)   { create(:status, is_closed: false) }
    let!(:done_status)   { create(:status, is_closed: false) }

    before { project.done_statuses = [done_status] }

    it "expands the closed link to status_id IN (is_closed ∪ done_statuses)" do
      props = query_props_from(helper.project_work_packages_closed_version_path(version))
      status_filter = props[:f].find { |f| f[:n] == "status" }

      expect(status_filter[:o]).to eq "="
      expect(status_filter[:v]).to include(closed_status.id.to_s, done_status.id.to_s)
      expect(status_filter[:v]).not_to include(open_status.id.to_s)
    end

    it "narrows the open link to status_id IN (is_closed=false − done_statuses)" do
      props = query_props_from(helper.project_work_packages_open_version_path(version))
      status_filter = props[:f].find { |f| f[:n] == "status" }

      expect(status_filter[:o]).to eq "="
      expect(status_filter[:v]).to include(open_status.id.to_s)
      expect(status_filter[:v]).not_to include(closed_status.id.to_s, done_status.id.to_s)
    end

    it "preserves the version_id filter" do
      props = query_props_from(helper.project_work_packages_closed_version_path(version))
      version_filter = props[:f].find { |f| f[:n] == "version" }

      expect(version_filter[:o]).to eq "="
      expect(version_filter[:v]).to eq version.id.to_s
    end
  end
end
