# frozen_string_literal: true

module Projects
  module Settings
    class LifecycleStageForm < ApplicationForm
      form do |f|
        f.select_list(
          name: :lifecycle_stage,
          label: I18n.t("activerecord.attributes.project.lifecycle_stage"),
          include_blank: I18n.t("label_not_set")
        ) do |list|
          Project.lifecycle_stages.each_key do |stage|
            list.with_option(
              value: stage,
              label: I18n.t("activerecord.attributes.project.lifecycle_stages.#{stage}",
                            default: stage.to_s.humanize)
            )
          end
        end
      end
    end
  end
end
