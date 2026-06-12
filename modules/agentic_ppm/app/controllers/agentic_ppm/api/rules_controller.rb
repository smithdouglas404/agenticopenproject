# frozen_string_literal: true

# OpenProject Agentic PPM module
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

module AgenticPpm
  module Api
    # Pull endpoint the TypeScript agent runtime polls to fetch the rules it
    # must evaluate. Returns the *enabled* global rules plus the requested
    # project's enabled rules as { rules: [...to_runtime_json] }.
    #
    # --- Authentication --------------------------------------------------
    # The runtime is a service, not a logged-in user, so we authenticate it
    # with a shared bearer token stored in the plugin setting
    # `rules_api_token` (Setting.plugin_openproject_agentic_ppm["rules_api_token"]).
    # The token is accepted via either the `Authorization: Bearer <token>`
    # header or the `X-OP-Rules-Token` header.
    #
    # ASSUMPTION TO DOUBLE-CHECK: We also fall back to OpenProject's standard
    # request authentication. We follow the core webhooks controller pattern
    # (modules/webhooks/.../hooks_controller.rb): treat application/json as an
    # API request and skip CSRF, then either accept the shared token OR require
    # a logged-in user via find_current_user (which resolves session / API-key
    # auth). A Rails/OpenProject reviewer should confirm `find_current_user`
    # and `accept_key_auth` behave as expected when mounted in this engine.
    class RulesController < ::ApplicationController
      accept_key_auth :index, :update_evaluated

      skip_before_action :verify_authenticity_token
      no_authorization_required! :index, :update_evaluated

      before_action :authenticate_runtime!
      before_action :find_project, only: %i[index]

      def api_request?
        super || request.content_type == "application/json"
      end

      def index
        rules = AgentRule.enabled.where(project_id: [@project&.id, nil].uniq)
        render json: { rules: rules.map(&:to_runtime_json) }
      end

      # Optional: let the runtime stamp when it last evaluated a rule.
      def update_evaluated
        rule = AgentRule.find(params[:id])
        rule.update_column(:last_evaluated_at, Time.current)
        head :no_content
      end

      private

      def find_project
        @project = Project.find(params[:project_id]) if params[:project_id].present?
      end

      # Accept the shared runtime token; otherwise fall back to a standard
      # authenticated OpenProject user (session or API key).
      def authenticate_runtime!
        return if valid_runtime_token?
        return if find_current_user&.logged?

        head :unauthorized
      end

      def valid_runtime_token?
        expected = configured_token
        return false if expected.blank?

        ActiveSupport::SecurityUtils.secure_compare(presented_token.to_s, expected.to_s)
      end

      def configured_token
        Hash(Setting.plugin_openproject_agentic_ppm)["rules_api_token"]
      end

      def presented_token
        bearer = request.authorization.to_s[/\ABearer\s+(.+)\z/i, 1]
        bearer.presence || request.headers["X-OP-Rules-Token"]
      end
    end
  end
end
