# frozen_string_literal: true

require "open_project/agentic_ppm/safe_blueprint"

module OpenProject
  module AgenticPpm
    # The single place the OpenProject <-> Smith Clarity ontology translation
    # lives. Both directions read from this registry:
    #
    #   * forward  (OpenProject -> graph): the projector asks which ontology
    #     class/properties a work package maps to and emits graph nodes/edges.
    #   * reverse  (agent finding -> OpenProject): an ontology subject such as
    #     "safe:Feature/123" resolves back to a target + record id so a
    #     recommendation can be attached to WorkPackage#123.
    #
    # This keeps the Rails module and the TypeScript agent runtime decoupled --
    # both speak ontology IRIs and neither hard-codes the other's schema.
    module Ontology
      WorkPackageTypeTarget = Struct.new(:type_name)
      ProjectLevelTarget    = Struct.new(:level)
      CustomFieldTarget     = Struct.new(:key)

      # Holds the bindings and exposes the small DSL used to declare them.
      class Registry
        attr_reader :class_bindings, :property_bindings

        def initialize
          @class_bindings = {}
          @property_bindings = {}
        end

        # --- DSL ---------------------------------------------------------
        def klass(iri, to:)
          @class_bindings[iri.to_s] = to
        end

        def prop(iri, to:)
          @property_bindings[iri.to_s] = to
        end

        def work_package_type(name) = WorkPackageTypeTarget.new(name)
        def project_level(level)    = ProjectLevelTarget.new(level)
        def custom_field(key)       = CustomFieldTarget.new(key)

        # --- Forward lookups --------------------------------------------
        def target_for_class(iri)    = @class_bindings[iri.to_s]
        def target_for_property(iri) = @property_bindings[iri.to_s]

        # --- Reverse lookup ---------------------------------------------
        # "safe:Feature/123" => { iri: "safe:Feature", id: 123, target: <WorkPackageTypeTarget> }
        def resolve_subject(subject)
          iri, id = subject.to_s.split("/", 2)
          { iri:, id: id&.to_i, target: target_for_class(iri) }
        end
      end

      class << self
        def registry
          @registry ||= Registry.new
        end

        def bind(&)
          registry.instance_eval(&)
          registry
        end

        def reset!
          @registry = Registry.new
        end

        # Rebuild the default bindings. Called from the engine to_prepare hook.
        def register!
          reset!
          define_default_bindings!
        end

        def define_default_bindings!
          bind do
            # Structure / hierarchy mapped onto the project tree.
            klass "safe:Portfolio",   to: project_level("Portfolio")
            klass "safe:ValueStream", to: project_level("ValueStream")
            klass "safe:ART",         to: project_level("ART")

            # Backlog hierarchy mapped onto work-package types.
            SafeBlueprint::TYPES.each do |type|
              klass type[:ontology], to: work_package_type(type[:name]) if type[:ontology]
            end

            # Datatype properties mapped onto native work-package attributes.
            prop "pm:taskName",            to: :subject
            prop "pm:taskStatus",          to: :status
            prop "pm:taskDescription",     to: :description
            prop "pm:assignee",            to: :assigned_to
            prop "pm:isAssignedTo",        to: :assigned_to
            prop "pm:hasStartDate",        to: :start_date
            prop "pm:hasDueDate",          to: :due_date
            prop "pm:effortHours",         to: :estimated_hours
            prop "pm:completionPercentage", to: :done_ratio

            # Custom-field-backed properties.
            SafeBlueprint::CUSTOM_FIELDS.each do |cf|
              Array(cf[:ontology]).each { |iri| prop iri, to: custom_field(cf[:key]) }
            end
          end
        end
      end
    end
  end
end
