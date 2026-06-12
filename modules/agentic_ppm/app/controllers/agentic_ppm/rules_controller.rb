# frozen_string_literal: true

module AgenticPpm
  # Project-scoped CRUD for agent rules/thresholds -- the *authoring* surface.
  # Mirrors RecommendationsController's auth pattern exactly: a menu_item, the
  # core ApplicationController#find_project_by_project_id (sets @project from
  # params[:project_id]) and #authorize (checks the project_module permission
  # for the current controller/action).
  #
  # Rules created here include both project-scoped rules and -- when no project
  # filter is applied -- the global rules that also apply to this project, so a
  # PM sees the full set governing their work.
  class RulesController < ::ApplicationController
    menu_item :agentic_ppm_rules

    before_action :find_project_by_project_id
    before_action :authorize
    before_action :find_rule, only: %i[edit update destroy]

    def index
      @rules = scoped_rules.order(created_at: :desc)
    end

    def new
      @rule = AgentRule.new(project_id: @project.id, enabled: true)
    end

    def create
      @rule = AgentRule.new(rule_params)
      @rule.project_id = @project.id
      if @rule.save
        flash[:notice] = t(:notice_successful_create)
        redirect_to project_agentic_ppm_rules_path(@project)
      else
        flash.now[:error] = @rule.errors.full_messages.join(", ")
        render :new
      end
    end

    def edit; end

    def update
      if @rule.update(rule_params)
        flash[:notice] = t(:notice_successful_update)
        redirect_to project_agentic_ppm_rules_path(@project)
      else
        flash.now[:error] = @rule.errors.full_messages.join(", ")
        render :edit
      end
    end

    def destroy
      @rule.destroy
      flash[:notice] = t(:notice_successful_delete)
      redirect_to project_agentic_ppm_rules_path(@project)
    end

    private

    # Project-scoped rules plus the global rules that also govern this project.
    def scoped_rules
      AgentRule.where(project_id: [@project.id, nil])
    end

    def find_rule
      # Only project-scoped rules are editable from a project surface; global
      # rules are managed centrally (admin), so scope the lookup to @project.
      @rule = AgentRule.where(project_id: @project.id).find(params[:id])
    end

    def rule_params
      params.require(:agent_rule).permit(
        :name, :description, :ontology_class, :metric, :operator,
        :threshold, :threshold2, :severity, :enabled,
        :notify_openproject, :notify_kyndral, :cooldown_minutes, :action_kind
      )
    end
  end
end
