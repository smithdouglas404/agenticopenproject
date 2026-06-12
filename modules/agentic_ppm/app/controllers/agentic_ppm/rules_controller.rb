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
      attrs = parsed_rule_params or return render(:new)

      @rule = AgentRule.new(attrs)
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
      attrs = parsed_rule_params or return render(:edit)

      if @rule.update(attrs)
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

    # :jdm is authored as text in the form, so we cannot permit it as a Hash
    # the usual way (Rails strong params reject unbounded jsonb/hash params).
    # Instead we permit it as a scalar String here, then JSON.parse it in
    # #parsed_rule_params and assign the resulting Hash to the model.
    def rule_params
      params.require(:agent_rule).permit(
        :name, :description, :ontology_class, :metric, :operator,
        :threshold, :threshold2, :severity, :enabled,
        :notify_openproject, :notify_kyndral, :cooldown_minutes, :action_kind,
        :kind, :jdm
      )
    end

    # Returns the permitted attributes with :jdm parsed from its text form into
    # a Hash, or nil if the supplied JDM text is not valid JSON. On failure it
    # sets a flash error and primes @rule (preserving the submitted values, jdm
    # excepted) so the caller can re-render the form.
    def parsed_rule_params
      attrs = rule_params
      raw = attrs[:jdm]

      if raw.is_a?(String) && raw.strip.present?
        begin
          attrs[:jdm] = JSON.parse(raw)
        rescue JSON::ParserError
          attrs = attrs.except(:jdm)
          @rule ||= AgentRule.new(project_id: @project.id)
          @rule.assign_attributes(attrs)
          @rule.errors.add(:jdm, t("agentic_ppm.errors.jdm_invalid_json"))
          flash.now[:error] = @rule.errors.full_messages.join(", ")
          return nil
        end
      elsif raw.is_a?(String)
        # Blank textarea => no decision graph; fall back to the column default.
        attrs[:jdm] = {}
      end

      attrs
    end
  end
end
