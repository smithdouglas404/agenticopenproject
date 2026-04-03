# frozen_string_literal: true

module Projects
  module Settings
    class ManagementForm < ApplicationForm
      form do |f|
        f.select_list(
          name: :portfolio_manager_id,
          label: I18n.t("activerecord.attributes.project.portfolio_manager"),
          include_blank: I18n.t("label_not_set")
        ) do |list|
          User.active.order(:lastname, :firstname).each do |user|
            list.with_option(value: user.id, label: user.name)
          end
        end

        f.select_list(
          name: :project_manager_id,
          label: I18n.t("activerecord.attributes.project.project_manager"),
          include_blank: I18n.t("label_not_set")
        ) do |list|
          User.active.order(:lastname, :firstname).each do |user|
            list.with_option(value: user.id, label: user.name)
          end
        end
      end
    end
  end
end
