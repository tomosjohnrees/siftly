# frozen_string_literal: true

module Siftly
  class Config
    attr_accessor :aggregator, :threshold, :failure_mode, :instrumenter
    attr_reader :enabled_filters

    def initialize(
      enabled_filters: [],
      filter_configs: {},
      aggregator: :score,
      threshold: 1.0,
      failure_mode: :record,
      instrumenter: nil
    )
      @enabled_filters = enabled_filters.map(&:to_sym)
      @filter_configs = normalize_filter_configs(filter_configs)
      @aggregator = aggregator
      @threshold = threshold
      @failure_mode = failure_mode
      @instrumenter = instrumenter
    end

    def use(key)
      key = key.to_sym
      @enabled_filters << key unless @enabled_filters.include?(key)
      key
    end

    def filter(key)
      filter_config = (@filter_configs[key.to_sym] ||= FilterConfig.new(key))
      yield(filter_config) if block_given?
      filter_config
    end

    def filter_config_for(key)
      existing = @filter_configs[key.to_sym]
      existing ? existing.merge({}) : FilterConfig.new(key)
    end

    def filter_configs
      @filter_configs.transform_values { |config| config.merge({}) }
    end

    def dup
      self.class.new(
        enabled_filters: enabled_filters.dup,
        filter_configs: filter_configs.transform_values(&:to_h),
        aggregator: aggregator,
        threshold: threshold,
        failure_mode: failure_mode,
        instrumenter: instrumenter
      )
    end

    private

    def normalize_filter_configs(filter_configs)
      filter_configs.each_with_object({}) do |(key, value), result|
        result[key.to_sym] =
          case value
          when FilterConfig
            value.merge({})
          when Hash
            FilterConfig.new(key, value)
          else
            raise ConfigurationError, "expected filter config for #{key.inspect} to be a Hash or FilterConfig"
          end
      end
    end
  end
end

