# frozen_string_literal: true

module Siftly
  class Pipeline
    VALID_FAILURE_MODES = %i[record open closed raise].freeze

    def initialize(filter_keys:, filter_configs:, aggregator:, threshold:, failure_mode:, instrumenter:)
      @filter_keys = filter_keys.map(&:to_sym)
      @filter_configs = filter_configs
      @aggregator = aggregator
      @threshold = threshold.to_f
      @failure_mode = normalize_failure_mode(failure_mode)
      @instrumenter = instrumenter || Instrumentation::NullInstrumenter.new
    end

    def call(value:, attribute: nil, record: nil, context: {})
      filter_results = filter_keys.map do |filter_key|
        run_filter(filter_key, value: value, attribute: attribute, record: record, context: context)
      end

      aggregation = resolve_aggregator.call(
        filter_results: filter_results,
        threshold: threshold,
        context: { value: value, attribute: attribute, record: record, context: context }
      )

      result = Result.new(
        spam: aggregation.fetch(:spam),
        score: aggregation.fetch(:score),
        filter_results: filter_results,
        reasons: filter_results.map(&:reason).compact,
        attribute: attribute,
        value_preview: preview(value),
        threshold: threshold,
        aggregator: aggregator_name
      )

      instrumenter.instrument(
        "siftly.pipeline.completed",
        attribute: attribute,
        filter_count: filter_keys.length,
        matched_filters: result.matches.map(&:filter),
        spam: result.spam?,
        score: result.score
      )

      result
    end

    private

    attr_reader :filter_keys, :filter_configs, :aggregator, :threshold, :failure_mode, :instrumenter

    def run_filter(filter_key, value:, attribute:, record:, context:)
      payload = { filter: filter_key, attribute: attribute }
      start = monotonic_time
      filter_class = Registry.resolve(filter_key)
      filter = filter_class.new(config: filter_configs.fetch(filter_key))

      instrumenter.instrument("siftly.filter.started", payload)

      filter_result = filter.call(value: value, attribute: attribute, record: record, context: context)
      raise InvalidFilterError, "#{filter_class} must return Siftly::FilterResult" unless filter_result.is_a?(FilterResult)

      duration = elapsed_ms(start)
      finalized = filter_result.with(duration_ms: duration)

      instrumenter.instrument("siftly.filter.finished", payload.merge(matched: finalized.matched?, score: finalized.score, duration_ms: duration))

      finalized
    rescue UnknownFilterError
      raise
    rescue StandardError => error
      raise if failure_mode == :raise

      duration = elapsed_ms(start)
      failed_result = build_failed_result(filter_key, error, duration)

      instrumenter.instrument(
        "siftly.filter.finished",
        payload.merge(matched: failed_result.matched?, score: failed_result.score, duration_ms: duration, error: error.message)
      )

      failed_result
    end

    def build_failed_result(filter_key, error, duration_ms)
      matched = failure_mode == :closed
      score = matched ? threshold : 0.0
      reason = matched ? "Filter #{filter_key} failed and failure_mode=:closed forced a spam match" : nil

      FilterResult.new(
        filter: filter_key,
        matched: matched,
        score: score,
        reason: reason,
        metadata: { exception_class: error.class.name },
        error: error.message,
        duration_ms: duration_ms
      )
    end

    def resolve_aggregator
      case aggregator
      when :any
        Aggregators::Any.new
      when :score, :weighted
        Aggregators::Score.new
      else
        return aggregator if aggregator.respond_to?(:call)

        raise InvalidAggregatorError, "unsupported aggregator #{aggregator.inspect}"
      end
    end

    def aggregator_name
      aggregator.is_a?(Symbol) ? aggregator : aggregator.class.name
    end

    def preview(value)
      value.to_s[0, 80]
    end

    def normalize_failure_mode(mode)
      mode = mode.to_sym
      return mode if VALID_FAILURE_MODES.include?(mode)

      raise ConfigurationError, "unsupported failure mode #{mode.inspect}"
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def elapsed_ms(start_time)
      ((monotonic_time - start_time) * 1000.0).round(3)
    end
  end
end
