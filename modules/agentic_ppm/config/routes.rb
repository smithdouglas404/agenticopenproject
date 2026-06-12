# frozen_string_literal: true

Rails.application.routes.draw do
  scope "projects/:project_id", as: "project" do
    resources :agentic_ppm_recommendations,
              controller: "agentic_ppm/recommendations",
              only: %i[index show update],
              as: :agentic_ppm_recommendations

    # Authoring CRUD for agent rules/thresholds.
    resources :agentic_ppm_rules,
              controller: "agentic_ppm/rules",
              as: :agentic_ppm_rules

    # JSON pull API the agent runtime polls for the rules it must evaluate:
    #   GET /projects/:project_id/agentic_ppm/api/rules.json
    get "agentic_ppm/api/rules",
        to: "agentic_ppm/api/rules#index",
        as: :agentic_ppm_api_rules,
        defaults: { format: "json" }
  end

  # Optional: runtime stamps last_evaluated_at for a rule (global path).
  #   PATCH /agentic_ppm/api/rules/:id/evaluated.json
  patch "agentic_ppm/api/rules/:id/evaluated",
        to: "agentic_ppm/api/rules#update_evaluated",
        as: :agentic_ppm_api_rule_evaluated,
        defaults: { format: "json" }

  # Global alerts ingestion: the runtime POSTs rule breaches here, which are
  # persisted as AgentRecommendations (the native Insights inbox).
  #   POST /agentic_ppm/api/alerts.json
  post "agentic_ppm/api/alerts",
       to: "agentic_ppm/api/alerts#create",
       as: :agentic_ppm_api_alerts,
       defaults: { format: "json" }
end
