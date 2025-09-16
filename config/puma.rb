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

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma.
#
threads_min_count = OpenProject::Configuration.web_min_threads
threads_max_count = OpenProject::Configuration.web_max_threads
threads threads_min_count, [threads_min_count, threads_max_count].max

# Specifies the address on which Puma will listen on to receive requests; default is localhost.
set_default_host ENV.fetch("HOST") { "localhost" }

# Specifies the port that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT") { 3000 }.to_i

# Specifies the environment that Puma will run in.
environment ENV.fetch("RAILS_ENV") { "development" }

# Specifies the number of `workers` to boot in clustered mode.
# Workers are forked webserver processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers do not work on JRuby or Windows (both of which do not support
# processes).
#
workers OpenProject::Configuration.web_workers

# Use the `preload_app!` method when specifying a `workers` number.
# This directive tells Puma to first boot the application and load code
# before forking the application. This takes advantage of Copy On Write
# process behavior so workers use less memory.
#
preload_app! if ENV["RAILS_ENV"] == "production"

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart unless ENV["RAILS_ENV"] == "production"

plugin :appsignal if ENV["APPSIGNAL_ENABLED"] == "true"

# activate statsd plugin only if a host is configured explicitly
if OpenProject::Configuration.statsd_host.present?
  module ConfigurationViaOpenProject
    def initialize
      host = OpenProject::Configuration.statsd_host
      port = OpenProject::Configuration.statsd_port

      Rails.logger.debug { "Enabling puma statsd plugin (publish to udp://#{host}:#{port})" }

      @host = host
      @port = port
    end
  end

  StatsdConnector.prepend ConfigurationViaOpenProject

  plugin :statsd
end

if OpenProject::Configuration.metrics["enabled"]
  require "prometheus_exporter/instrumentation"

  # module AdditionalPumaStats
  #   def collect_worker_status(metric, status)
  #     super

  #     metric[:requests_count] ||= 0
  #     metric[:requests_count] += status["requests_count"]

  #     puts "Metrics: #{metric.inspect}"
  #   end

  #   def collect_puma_stats(metric)
  #     super

  #     puts "COLLECT PUMA STATS METRIC: #{metric.inspect}"
  #     puts "  #{::Puma.stats}"
  #   end
  # end

  # PrometheusExporter::Instrumentation::Puma.prepend AdditionalPumaStats

  def instrument_puma!
    require "prometheus_exporter/client"

    unless PrometheusExporter::Instrumentation::Puma.started?
      PrometheusExporter::Client.default = PrometheusExporter::Client.new(
        host: "localhost",
        port: OpenProject::Configuration.metrics["port"]
      )

      PrometheusExporter::Instrumentation::Puma.start
    end
  end

  def start_exporter!
    require "prometheus_exporter/server"

    server = PrometheusExporter::Server::WebServer.new bind: "0.0.0.0", port: OpenProject::Configuration.metrics["port"]
    server.start
  end

  if OpenProject::Configuration.web["workers"] > 0
    before_fork do
      start_exporter!
    end

    after_worker_boot do
      instrument_puma!
    end
  else
    start_exporter!
    instrument_puma!
  end
end
