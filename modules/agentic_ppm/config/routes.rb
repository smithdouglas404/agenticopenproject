# frozen_string_literal: true

Rails.application.routes.draw do
  scope "projects/:project_id", as: "project" do
    resources :agentic_ppm_recommendations,
              controller: "agentic_ppm/recommendations",
              only: %i[index show update],
              as: :agentic_ppm_recommendations
  end
end
