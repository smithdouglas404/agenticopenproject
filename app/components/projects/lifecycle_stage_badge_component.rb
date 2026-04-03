# frozen_string_literal: true

class Projects::LifecycleStageBadgeComponent < ApplicationComponent
  include OpPrimer::ComponentHelpers
  include Primer::ClassNameHelper

  STAGE_COLORS = {
    "discovery" => :accent,
    "design" => :accent,
    "build" => :attention,
    "test" => :attention,
    "pre_launch" => :severe,
    "live" => :success,
    "support" => :done,
    "archived" => :default
  }.freeze

  def initialize(project:, **system_arguments)
    super

    @project = project
    @system_arguments = system_arguments
  end

  def render?
    @project.lifecycle_stage.present?
  end

  def name
    I18n.t("activerecord.attributes.project.lifecycle_stages.#{@project.lifecycle_stage}",
           default: @project.lifecycle_stage.to_s.humanize)
  end

  def scheme
    STAGE_COLORS[@project.lifecycle_stage.to_s] || :default
  end
end
