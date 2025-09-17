require "prometheus_exporter/instrumentation"

module PrometheusExporter::Instrumentation
  module CustomPumaStats
    def collect_worker_status(metric, status)
      super

      metric[:requests_count] ||= 0
      metric[:requests_count] += status["requests_count"]
    end
  end

  class CustomPuma < Puma
    prepend CustomPumaStats
  end
end
