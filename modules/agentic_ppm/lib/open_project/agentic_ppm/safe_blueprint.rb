# frozen_string_literal: true

module OpenProject
  module AgenticPpm
    # The single declarative source of the SAFe 6.0 configuration this module
    # provisions in OpenProject. Both the seeder
    # (AgenticPpm::SeedSafeConfigurationService) and the ontology binding
    # (OpenProject::AgenticPpm::Ontology) read from here, so changing a type or
    # field in one place keeps the seeded configuration and the
    # ontology <-> OpenProject mapping in sync.
    #
    # See agentic-ppm/docs/03-openproject-mapping.md for the rationale.
    module SafeBlueprint
      # OpenProject work-package Types representing the SAFe backlog hierarchy
      # and the K360 governance/OKR objects. :ontology is the Smith Clarity
      # ontology class the type stands in for.
      TYPES = [
        { name: "Strategic Theme",       ontology: "safe:StrategicTheme",       color: "blue",    in_roadmap: true },
        { name: "Epic",                  ontology: "safe:Epic",                 color: "purple",  in_roadmap: true },
        { name: "Capability",            ontology: "safe:Capability",           color: "magenta", in_roadmap: true },
        { name: "Feature",               ontology: "safe:Feature",              color: "teal",    in_roadmap: true },
        { name: "User Story",            ontology: "safe:Story",                color: "green" },
        { name: "Enabler",               ontology: "safe:Enabler",              color: "grey" },
        { name: "Risk",                  ontology: "pm:Risk",                   color: "red" },
        { name: "Objective",             ontology: "k360:Objective",            color: "orange" },
        { name: "Key Result",            ontology: "k360:KeyResult",            color: "yellow" },
        { name: "Governance Checkpoint", ontology: "k360:ComplianceCheckpoint", color: "red",     is_milestone: true }
      ].freeze

      # Custom fields backing the WSJF / Epic / EVM ontology properties, and the
      # types they attach to. :ontology lists the ontology property IRIs the
      # field stands in for; :readonly marks agent-derived (computed) fields.
      CUSTOM_FIELDS = [
        { key: "story_points",         name: "Story points",                              format: "int",   on_types: %w[User\ Story Feature], ontology: ["pm:storyPoints"] },
        { key: "wsjf_score",           name: "WSJF score",                                format: "float", on_types: ["Feature"], ontology: ["safe:wsjfScore"], readonly: true },
        { key: "business_value",       name: "Business value",                            format: "int",   on_types: ["Feature"], ontology: ["safe:businessValue"] },
        { key: "time_criticality",     name: "Time criticality",                          format: "int",   on_types: ["Feature"], ontology: ["safe:timeCriticality"] },
        { key: "risk_reduction",       name: "Risk reduction / opportunity enablement",   format: "int",   on_types: ["Feature"], ontology: ["safe:riskReduction"] },
        { key: "job_size",             name: "Job size",                                  format: "int",   on_types: ["Feature"], ontology: ["safe:jobSize"] },
        { key: "epic_type",            name: "Epic type",                                 format: "list",  on_types: ["Epic"], possible_values: %w[Business Enabler], ontology: ["safe:epicType"] },
        { key: "lean_business_case",   name: "Lean business case",                        format: "text",  on_types: ["Epic"], ontology: ["safe:leanBusinessCase"] },
        { key: "mvp_statement",        name: "MVP statement",                             format: "text",  on_types: ["Epic"], ontology: ["safe:mvpStatement"] },
        { key: "hypothesis_statement", name: "Hypothesis statement",                      format: "text",  on_types: ["Epic"], ontology: ["safe:hypothesisStatement"] },
        { key: "cpi_value",            name: "CPI (cost performance index)",              format: "float", on_types: %w[Feature Epic], ontology: ["pm:cpiValue"], readonly: true },
        { key: "spi_value",            name: "SPI (schedule performance index)",          format: "float", on_types: %w[Feature Epic], ontology: ["pm:spiValue"], readonly: true }
      ].freeze

      # SAFe timeboxes are represented as OpenProject Versions tagged by kind.
      VERSION_KINDS = %w[PI Sprint].freeze

      module_function

      def type_names
        TYPES.map { |t| t[:name] }
      end

      def custom_field_keys
        CUSTOM_FIELDS.map { |cf| cf[:key] }
      end

      def custom_field(key)
        CUSTOM_FIELDS.find { |cf| cf[:key] == key }
      end
    end
  end
end
