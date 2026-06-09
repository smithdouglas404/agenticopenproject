# frozen_string_literal: true

require "open_project/agentic_ppm/ontology"

RSpec.describe OpenProject::AgenticPpm::Ontology do
  subject(:registry) do
    described_class.register!
    described_class.registry
  end

  describe "forward class bindings" do
    it "maps SAFe backlog classes to work-package types" do
      expect(registry.target_for_class("safe:Feature").type_name).to eq("Feature")
      expect(registry.target_for_class("safe:Epic").type_name).to eq("Epic")
      expect(registry.target_for_class("safe:Story").type_name).to eq("User Story")
    end

    it "maps portfolio-level classes to project levels" do
      expect(registry.target_for_class("safe:Portfolio").level).to eq("Portfolio")
      expect(registry.target_for_class("safe:ValueStream").level).to eq("ValueStream")
    end
  end

  describe "forward property bindings" do
    it "maps native properties to work-package attributes" do
      expect(registry.target_for_property("pm:taskStatus")).to eq(:status)
      expect(registry.target_for_property("pm:hasDueDate")).to eq(:due_date)
    end

    it "maps WSJF/flow properties to custom fields" do
      expect(registry.target_for_property("safe:wsjfScore").key).to eq("wsjf_score")
      expect(registry.target_for_property("pm:storyPoints").key).to eq("story_points")
    end
  end

  describe "#resolve_subject (reverse)" do
    it "parses an ontology subject IRI into a target and record id" do
      result = registry.resolve_subject("safe:Feature/123")

      expect(result[:iri]).to eq("safe:Feature")
      expect(result[:id]).to eq(123)
      expect(result[:target].type_name).to eq("Feature")
    end

    it "tolerates a subject without an id" do
      expect(registry.resolve_subject("safe:Feature")).to include(iri: "safe:Feature", id: nil)
    end
  end

  it "keeps the seeded blueprint and the binding in sync" do
    OpenProject::AgenticPpm::SafeBlueprint::TYPES.each do |type|
      expect(registry.target_for_class(type[:ontology]).type_name).to eq(type[:name])
    end
  end
end
