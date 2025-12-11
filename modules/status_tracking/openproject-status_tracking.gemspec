# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "openproject-status_tracking"
  s.version     = "1.0.0"
  s.authors     = "Andri Kurniawan"
  s.email       = "andri.kurniawan@sg-edts.com"
  s.summary     = "OpenProject Work Package Status Tracking"
  s.description = "Automatically sets started_at and done_at when work package status changes"
  s.license     = "GPLv3"

  s.files = Dir["{db,lib,frontend}/**/*"]
  s.metadata["rubygems_mfa_required"] = "true"
end
