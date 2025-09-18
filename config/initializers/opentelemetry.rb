# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++
require_relative "../../lib_static/open_project/opentelemetry"

Rails.application.configure do
  if OpenProject::Configuration.opentelemetry_enabled?

    require "opentelemetry/sdk"
    require "opentelemetry-exporter-otlp"
    require "opentelemetry-instrumentation-all"

    # add log tags for log correlation
    if config.log_tags
      config.log_tags += [
        ->(*) { "trace_id=#{OpenTelemetry::Trace.current_span.context.hex_trace_id}" },
        ->(*) { "span_id=#{OpenTelemetry::Trace.current_span.context.hex_span_id}" }
      ]
    end

    OpenTelemetry::SDK.configure do |c|
      c.add_span_processor(
        OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
          OpenTelemetry::Exporter::OTLP::Exporter.new
        )
      )

      c.resource = OpenTelemetry::SDK::Resources::Resource.create(
        {
          "deployment.environment" => Rails.env,
          "service.namespace" => "openproject",
          "service.instance.id" => Socket.gethostname
        }.transform_values(&:to_s)
      )

      c.use_all
    end

    # Extend the core log delegator
    handler = OpenProject::OpenTelemetry.method(:exception_handler)
    OpenProject::Logging::LogDelegator.register(:opentelemetry, handler)
  end
end
