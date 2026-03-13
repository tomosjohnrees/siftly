# frozen_string_literal: true

module Siftly
  class Checker
    def initialize(config:)
      @config = config
    end

    def call(
      value:,
      attribute: nil,
      record: nil,
      context: {},
      filters: nil,
      filter_overrides: {},
      aggregator: nil,
      threshold: nil,
      failure_mode: nil,
      instrumenter: nil
    )
      active_filters = resolve_filters(filters)
      runtime_filter_configs = build_filter_configs(active_filters, filter_overrides)

      Pipeline.new(
        filter_keys: active_filters,
        filter_configs: runtime_filter_configs,
        aggregator: aggregator || config.aggregator,
        threshold: threshold || config.threshold,
        failure_mode: failure_mode || config.failure_mode,
        instrumenter: instrumenter || config.instrumenter
      ).call(value: value, attribute: attribute, record: record, context: context)
    end

    private

    attr_reader :config

    def resolve_filters(filters)
      (filters || config.enabled_filters).map(&:to_sym)
    end

    def build_filter_configs(filter_keys, filter_overrides)
      filter_keys.each_with_object({}) do |filter_key, result|
        overrides = filter_overrides.fetch(filter_key, filter_overrides.fetch(filter_key.to_s, {}))
        result[filter_key] = config.filter_config_for(filter_key).merge(overrides)
      end
    end
  end
end
