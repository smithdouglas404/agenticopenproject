# frozen_string_literal: true

class Queries::Projects::Filters::LifecycleStageFilter < Queries::Projects::Filters::Base
  def allowed_values
    @allowed_values ||= Project.lifecycle_stages.map do |stage, id|
      [I18n.t("activerecord.attributes.project.lifecycle_stages.#{stage}", default: stage.to_s.humanize), id.to_s]
    end
  end

  def type
    :list_optional
  end

  def where
    operator_strategy.sql_for_field(values, model.table_name, :lifecycle_stage)
  end

  def self.key
    :lifecycle_stage
  end

  def human_name
    I18n.t("label_lifecycle_stage_filter")
  end
end
