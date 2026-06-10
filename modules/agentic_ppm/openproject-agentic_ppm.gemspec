# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "openproject-agentic_ppm"
  s.version     = "0.1.0"
  s.authors     = "Smith Family USA"
  s.summary     = "OpenProject Agentic PPM"
  s.description = "Agentic Portfolio & Project Management: SAFe configuration, the " \
                  "Smith Clarity ontology binding, and the agent recommendation store."
  s.license     = "GPLv3"

  s.files = Dir["{app,config,db,lib}/**/*"]
  s.metadata["rubygems_mfa_required"] = "true"
end
