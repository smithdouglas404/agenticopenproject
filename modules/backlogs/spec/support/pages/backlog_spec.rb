# frozen_string_literal: true

require "rails_helper"
require_relative "backlog"

RSpec.describe Pages::Backlog do
  let(:project) { build_stubbed(:project) }
  let(:backlog_page) { described_class.new(project) }
  let(:work_package) { build_stubbed(:work_package) }
  let(:target_work_package) { build_stubbed(:work_package) }
  let(:sprint) { build_stubbed(:sprint) }

  describe "#drag_work_package" do
    it "raises when neither before nor into is provided" do
      expect { backlog_page.drag_work_package(work_package) }
        .to raise_error(ArgumentError, "You must specify either before or into")
    end

    it "raises when both before and into are provided" do
      expect { backlog_page.drag_work_package(work_package, before: target_work_package, into: sprint) }
        .to raise_error(ArgumentError, "You must specify either before or into")
    end
  end
end
