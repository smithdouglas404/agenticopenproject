module OpenProject::StatusTracking
  module Patches
    module WorkPackagePatch
      def self.included(base)
        base.class_eval do
          before_save :set_status_timestamps, if: :will_save_change_to_status_id?
        end
      end

      private

      def set_status_timestamps
        old_status, new_status = status_id_change_to_be_saved

        # new to "In Progress" status
        if new_status == 7 && old_status == 1
          self.started_at ||= Time.current
        end

        # "In Progress" to "Done" status
        if new_status == 12 && old_status == 7
          self.done_at ||= Time.current
        end
      end
    end
  end
end

WorkPackage.include OpenProject::StatusTracking::Patches::WorkPackagePatch
