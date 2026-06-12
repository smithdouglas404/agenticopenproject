# frozen_string_literal: true

# OpenProject Agentic PPM module
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# Adds GoRules JDM (JSON Decision Model) support to agent rules. A rule is
# now either a simple "threshold" comparison (the original behaviour) or a
# full "decision" graph carried as a GoRules JDM in :jdm, evaluated by the
# runtime's ZEN engine (see src/rules/zenEvaluator.ts).
class AddDecisionToAgenticPpmAgentRules < ActiveRecord::Migration[7.1]
  def change
    add_column :agentic_ppm_agent_rules, :kind, :string, null: false, default: "threshold"
    add_column :agentic_ppm_agent_rules, :jdm, :jsonb, null: false, default: {}

    add_index :agentic_ppm_agent_rules, :kind
  end
end
