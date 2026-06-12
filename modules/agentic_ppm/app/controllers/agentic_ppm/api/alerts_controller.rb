# frozen_string_literal: true

# OpenProject Agentic PPM module
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

module AgenticPpm
  module API
    # Ingestion endpoint the agent runtime POSTs to when a rule breaches.
    # Each breach is persisted as an AgentRecommendation (finding_type
    # "rule_breach") so it surfaces in OpenProject's native Insights inbox for
    # human triage. Same shared-token auth as API::RulesController.
    #
    # ASSUMPTION TO DOUBLE-CHECK: identical to API::RulesController -- token in
    # `Authorization: Bearer` / `X-OP-Rules-Token`, falling back to a standard
    # authenticated OpenProject user. Mirrors the core webhooks controller's
    # CSRF/authorization handling.
    class AlertsController < ::ApplicationController
      accept_key_auth :create

      skip_before_action :verify_authenticity_token
      no_authorization_required! :create

      before_action :authenticate_runtime!

      def api_request?
        super || request.content_type == "application/json"
      end

      def create
        subject = params[:ontology_subject].to_s
        resolved = resolve_subject(subject)

        recommendation = AgentRecommendation.new(
          ontology_subject: subject,
          agent: params[:agent].presence || "RulesAgent",
          finding_type: "rule_breach",
          title: params[:title],
          body: params[:body],
          severity: params[:severity],
          confidence: params[:confidence],
          evidence: {
            rule_id: params[:rule_id],
            metric: params[:metric],
            observed_value: params[:observed_value],
            threshold: params[:threshold],
            operator: params[:operator]
          }.compact,
          project_id: resolved[:project_id],
          work_package_id: resolved[:work_package_id]
        )

        if recommendation.save
          render json: { id: recommendation.id }, status: :created
        else
          render json: { errors: recommendation.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      # Resolve an ontology subject IRI (e.g. "safe:Feature/123") back to the
      # OpenProject record it concerns, reusing the Ontology registry. A subject
      # mapping to a work-package type yields a work_package_id (and its
      # project); a project-level subject yields a project_id.
      def resolve_subject(subject)
        return {} if subject.blank?

        resolved = OpenProject::AgenticPpm::Ontology.registry.resolve_subject(subject)
        target = resolved[:target]
        id = resolved[:id]
        return {} if id.blank?

        case target
        when OpenProject::AgenticPpm::Ontology::WorkPackageTypeTarget
          wp = WorkPackage.find_by(id:)
          { work_package_id: wp&.id, project_id: wp&.project_id }
        when OpenProject::AgenticPpm::Ontology::ProjectLevelTarget
          { project_id: Project.find_by(id:)&.id }
        else
          {}
        end
      end

      def authenticate_runtime!
        return if valid_runtime_token?
        return if find_current_user&.logged?

        head :unauthorized
      end

      def valid_runtime_token?
        expected = Hash(Setting.plugin_openproject_agentic_ppm)["rules_api_token"]
        return false if expected.blank?

        ActiveSupport::SecurityUtils.secure_compare(presented_token.to_s, expected.to_s)
      end

      def presented_token
        bearer = request.authorization.to_s[/\ABearer\s+(.+)\z/i, 1]
        bearer.presence || request.headers["X-OP-Rules-Token"]
      end
    end
  end
end
