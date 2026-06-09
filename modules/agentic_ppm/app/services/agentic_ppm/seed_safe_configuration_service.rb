# frozen_string_literal: true

module AgenticPpm
  # Idempotent seeder that provisions the SAFe configuration described by
  # OpenProject::AgenticPpm::SafeBlueprint:
  #
  #   1. work-package Types for the SAFe backlog hierarchy + K360 objects, and
  #   2. the WSJF / Epic / EVM CustomFields, attached to the right types.
  #
  # Re-runnable and non-destructive: records are looked up by name and updated
  # in place; nothing is deleted, and existing type/field associations are kept.
  # Run from a console or an installer rake task:
  #
  #   AgenticPpm::SeedSafeConfigurationService.new.call
  #
  # NOTE: default workflows and per-project enablement are intentionally out of
  # scope for this first iteration (tracked in agentic-ppm/docs/06-roadmap.md);
  # this service only establishes the types and fields the ontology binding
  # depends on.
  class SeedSafeConfigurationService
    Blueprint = OpenProject::AgenticPpm::SafeBlueprint

    def call
      ActiveRecord::Base.transaction do
        types  = seed_types
        fields = seed_custom_fields
        attach_fields_to_types(types, fields)
      end
      true
    end

    private

    # @return [Hash{String => Type}] type name => persisted Type
    def seed_types
      Blueprint::TYPES.each_with_object({}) do |data, acc|
        type = Type.find_or_initialize_by(name: data[:name])
        type.is_milestone  = data.fetch(:is_milestone, false)
        type.is_in_roadmap = data.fetch(:in_roadmap, false)
        type.is_default    = false if type.new_record?
        type.color_id    ||= color_id_for(data[:color])
        type.position    ||= next_type_position
        type.save!
        acc[data[:name]] = type
      end
    end

    # @return [Hash{String => CustomField}] field key => persisted CustomField
    def seed_custom_fields
      Blueprint::CUSTOM_FIELDS.each_with_object({}) do |data, acc|
        cf = WorkPackageCustomField.find_or_initialize_by(name: data[:name])
        cf.field_format = data[:format]
        cf.is_required  = false
        cf.editable     = !data[:readonly]
        cf.possible_values = data[:possible_values] if data[:possible_values].present?
        cf.save!
        acc[data[:key]] = cf
      end
    end

    def attach_fields_to_types(types, fields)
      Blueprint::CUSTOM_FIELDS.each do |data|
        cf = fields[data[:key]]
        Array(data[:on_types]).each do |type_name|
          type = types[type_name]
          next if type.nil? || type.custom_fields.include?(cf)

          type.custom_fields << cf
        end
      end
    end

    def color_id_for(name)
      return if name.blank?

      Color.find_by(name: name.to_s.titleize)&.id
    end

    def next_type_position
      (Type.maximum(:position) || 0) + 1
    end
  end
end
