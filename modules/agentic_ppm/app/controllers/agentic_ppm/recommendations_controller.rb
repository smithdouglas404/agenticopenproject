# frozen_string_literal: true

module AgenticPpm
  # Minimal read/triage surface for agent recommendations within a project --
  # the "Insights inbox". The polished cross-project front end layers on top of
  # this and the embedded OpenProject UIs (see docs/08).
  class RecommendationsController < ::ApplicationController
    menu_item :agentic_ppm

    before_action :find_project_by_project_id
    before_action :authorize
    before_action :find_recommendation, only: %i[show update]

    def index
      @recommendations = scoped_recommendations.order(created_at: :desc)
    end

    def show; end

    # Human-in-the-loop triage: accept / dismiss / apply a recommendation.
    def update
      if @recommendation.update(status: params.require(:status))
        flash[:notice] = t(:notice_successful_update)
      else
        flash[:error] = @recommendation.errors.full_messages.join(", ")
      end
      redirect_to project_agentic_ppm_recommendations_path(@project)
    end

    private

    def scoped_recommendations
      AgentRecommendation.where(project_id: @project.id)
    end

    def find_recommendation
      @recommendation = scoped_recommendations.find(params[:id])
    end
  end
end
