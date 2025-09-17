# frozen_string_literal: true

require "prometheus_exporter/server"

module PrometheusExporter::Server
  class CustomPumaCollector < PumaCollector
    CUSTOM_PUMA_GAUGES = PUMA_GAUGES.merge(
      requests_count: "The number of most recent requests"
    )

    # we simply copied this code from the original puma collector
    # as it doesn't offer any extension points
    def metrics # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
      return [] if @puma_metrics.length == 0 # rubocop:disable Style/ZeroLengthPredicate

      metrics = {}

      @puma_metrics.map do |m|
        labels = {}
        labels.merge!(phase: m["phase"]) if m["phase"] # rubocop:disable Performance/RedundantMerge
        labels.merge!(m["custom_labels"]) if m["custom_labels"]
        labels.merge!(m["metric_labels"]) if m["metric_labels"]

        # here we merely changed PUMA_GAUGES to CUSTOM_PUMA_GAUGES to introduce our own extra gauges
        CUSTOM_PUMA_GAUGES.map do |k, help|
          k = k.to_s
          if v = m[k]
            g = metrics[k] ||= PrometheusExporter::Metric::Gauge.new("puma_#{k}", help)
            g.observe(v, labels)
          end
        end
      end

      metrics.values
    end
  end
end
