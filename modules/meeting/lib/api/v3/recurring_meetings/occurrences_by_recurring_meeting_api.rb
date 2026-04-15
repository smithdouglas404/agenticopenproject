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

module API
  module V3
    module RecurringMeetings
      class OccurrencesByRecurringMeetingAPI < ::API::OpenProjectAPI
        helpers do
          def build_occurrence(start_time:, scheduled_meeting: nil)
            Occurrence.new(
              start_time:,
              recurring_meeting_id: @recurring_meeting.id,
              meeting_id: scheduled_meeting&.meeting_id,
              cancelled: scheduled_meeting&.cancelled || false
            )
          end

          def occurrences_from_scheduled(scheduled_meetings)
            scheduled_meetings.map { |sm| build_occurrence(start_time: sm.start_time, scheduled_meeting: sm) }
          end

          def occurrence_collection(occurrences, self_link:)
            OccurrenceCollectionRepresenter.new(occurrences, self_link:, current_user:)
          end

          def persisted_upcoming
            @recurring_meeting.scheduled_meetings.upcoming.index_by(&:start_time)
          end

          def opened_start_times(persisted)
            persisted
              .select { |_, sm| sm.meeting_id.present? && !sm.cancelled }
              .keys
              .to_set
          end

          def computed_start_times(opened_times, limit)
            from_time = Time.current - (@recurring_meeting.template&.duration || 1).hours
            @recurring_meeting
              .scheduled_occurrences(limit: limit + opened_times.size, from_time:)
              .reject { |t| opened_times.include?(t) }
              .first(limit)
          end

          def build_upcoming_occurrences(limit: 20)
            persisted = persisted_upcoming
            opened_times = opened_start_times(persisted)
            all_times = (opened_times.to_a + computed_start_times(opened_times, limit)).sort
            all_times.map { |t| build_occurrence(start_time: t, scheduled_meeting: persisted[t]) }
          end
        end

        namespace :occurrences do
          namespace :upcoming do
            params do
              optional :limit, type: Integer, default: 20, desc: "Number of occurrences to return"
            end

            get do
              occurrence_collection(
                build_upcoming_occurrences(limit: declared_params[:limit]),
                self_link: api_v3_paths.recurring_meeting_occurrences_upcoming(@recurring_meeting.id)
              )
            end
          end

          namespace :past do
            get do
              occurrence_collection(
                occurrences_from_scheduled(@recurring_meeting.scheduled_meetings.past.not_cancelled),
                self_link: api_v3_paths.recurring_meeting_occurrences_past(@recurring_meeting.id)
              )
            end
          end

          namespace :cancelled do
            get do
              occurrence_collection(
                occurrences_from_scheduled(@recurring_meeting.scheduled_meetings.cancelled),
                self_link: api_v3_paths.recurring_meeting_occurrences_cancelled(@recurring_meeting.id)
              )
            end
          end

          namespace :open do
            get do
              occurrence_collection(
                occurrences_from_scheduled(@recurring_meeting.scheduled_meetings.instantiated.not_cancelled),
                self_link: api_v3_paths.recurring_meeting_occurrences_open(@recurring_meeting.id)
              )
            end
          end

          route_param :start_time, type: DateTime, desc: "Occurrence start time (ISO 8601)" do
            namespace :init do
              post do
                start_time = declared_params[:start_time]
                call = ::RecurringMeetings::InitOccurrenceService
                         .new(user: current_user, recurring_meeting: @recurring_meeting)
                         .call(start_time:)

                if call.success?
                  status 201
                  ::API::V3::Meetings::MeetingRepresenter.create(call.result, current_user:, embed_links: true)
                else
                  fail ::API::Errors::ErrorBase.create_and_merge_errors(call.errors)
                end
              end
            end

            delete do
              start_time = declared_params[:start_time]
              authorize_in_project(:edit_meetings, project: @recurring_meeting.project)

              scheduled = @recurring_meeting.scheduled_meetings.find_or_initialize_by(start_time:)

              if scheduled.meeting_id.present?
                fail ::API::Errors::Conflict.new(
                  message: "Cannot cancel an already instantiated occurrence. Delete the meeting instead."
                )
              end

              scheduled.cancelled = true
              if scheduled.save
                status 204
              else
                fail ::API::Errors::ErrorBase.create_and_merge_errors(scheduled.errors)
              end
            end
          end
        end
      end
    end
  end
end
