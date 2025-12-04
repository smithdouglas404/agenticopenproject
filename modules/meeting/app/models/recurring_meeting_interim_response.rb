# frozen_string_literal: true

class RecurringMeetingInterimResponse < ApplicationRecord
  belongs_to :recurring_meeting
  belongs_to :user

  enum :participation_status, {
    needs_action: "needs-action",
    accepted: "accepted",
    declined: "declined",
    tentative: "tentative",
    # delegated: "delegated", # We currently do not support delegation
    unknown: "unknown" # this status is used for existing participants when introducing the field
  }, prefix: :participation
end
