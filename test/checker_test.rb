# frozen_string_literal: true

require "test_helper"

class CheckerTest < Minitest::Test
  class MatchFilter < Siftly::Filter
    register_as :match_filter

    def call(value:, attribute: nil, record: nil, context: {})
      result(
        matched: value.to_s.include?(config.fetch(:needle, "spam")),
        score: config.fetch(:weight, 0.6),
        reason: "matched #{config.fetch(:needle, 'spam')}",
        metadata: { source: context[:source] }
      )
    end
  end

  class SecondaryMatchFilter < Siftly::Filter
    register_as :secondary_match

    def call(value:, attribute: nil, record: nil, context: {})
      result(matched: value.to_s.include?("promo"), score: config.fetch(:weight, 0.5), reason: "matched promo")
    end
  end

  class ExplodingFilter < Siftly::Filter
    register_as :exploding_filter

    def call(value:, attribute: nil, record: nil, context: {})
      raise "kaboom"
    end
  end

  class RecordingInstrumenter
    attr_reader :events

    def initialize
      @events = []
    end

    def instrument(event, payload = {})
      events << [event, payload]
      yield(payload) if block_given?
    end
  end

  class CustomAggregator
    def call(filter_results:, threshold:, context:)
      { spam: filter_results.count(&:matched?) >= 2, score: filter_results.sum(&:score) }
    end
  end

  def setup
    super
    Siftly::Registry.register(MatchFilter)
    Siftly::Registry.register(SecondaryMatchFilter)
    Siftly::Registry.register(ExplodingFilter)
  end

  def test_score_aggregation_uses_global_configuration
    Siftly.configure do |config|
      config.use :match_filter
      config.use :secondary_match
      config.threshold = 1.0

      config.filter :match_filter do |filter|
        filter.needle = "offer"
        filter.weight = 0.6
      end

      config.filter :secondary_match do |filter|
        filter.weight = 0.5
      end
    end

    result = Siftly.check(value: "offer promo", attribute: :message, context: { source: "contact_form" })

    assert result.spam?
    assert_in_delta 1.1, result.score, 0.001
    assert_equal %i[match_filter secondary_match], result.matches.map(&:filter)
    assert_equal ["matched offer", "matched promo"], result.reasons
  end

  def test_explicit_filters_and_overrides_are_applied_per_call
    Siftly.configure do |config|
      config.use :secondary_match
      config.filter(:match_filter) { |filter| filter.needle = "ignored" }
    end

    result = Siftly.check(
      value: "special phrase",
      filters: [:match_filter],
      filter_overrides: { match_filter: { needle: "special phrase", weight: 0.9 } },
      threshold: 0.5
    )

    assert result.spam?
    assert_equal [:match_filter], result.matches.map(&:filter)
    assert_in_delta 0.9, result.score, 0.001
  end

  def test_any_aggregator_marks_spam_on_first_match
    Siftly.configure do |config|
      config.use :match_filter
      config.use :secondary_match
      config.aggregator = :any
      config.filter(:match_filter) { |filter| filter.needle = "offer" }
    end

    result = Siftly.check(value: "offer only")

    assert result.spam?
    assert_equal [:match_filter], result.matches.map(&:filter)
  end

  def test_custom_aggregator_is_supported
    Siftly.configure do |config|
      config.use :match_filter
      config.use :secondary_match
      config.aggregator = CustomAggregator.new
      config.filter(:match_filter) { |filter| filter.needle = "offer" }
    end

    result = Siftly.check(value: "offer promo")

    assert result.spam?
    assert_equal "CheckerTest::CustomAggregator", result.aggregator
  end

  def test_erroring_filters_are_recorded_by_default
    Siftly.configure do |config|
      config.use :exploding_filter
      config.threshold = 0.5
    end

    result = Siftly.check(value: "anything")

    refute result.spam?
    assert_equal 1, result.errors.length
    assert_equal :exploding_filter, result.errors.first.filter
    assert_equal "kaboom", result.errors.first.error
  end

  def test_closed_failure_mode_forces_a_match
    Siftly.configure do |config|
      config.use :exploding_filter
      config.failure_mode = :closed
      config.threshold = 0.8
    end

    result = Siftly.check(value: "anything")

    assert result.spam?
    assert_equal [:exploding_filter], result.matches.map(&:filter)
    assert_in_delta 0.8, result.score, 0.001
  end

  def test_raise_failure_mode_bubbles_errors
    Siftly.configure do |config|
      config.use :exploding_filter
      config.failure_mode = :raise
    end

    assert_raises(RuntimeError) do
      Siftly.check(value: "anything")
    end
  end

  def test_unknown_filters_raise_at_execution_time
    error = assert_raises(Siftly::UnknownFilterError) do
      Siftly.check(value: "anything", filters: [:missing])
    end

    assert_match(/missing/, error.message)
  end

  def test_instrumentation_receives_filter_and_pipeline_events
    instrumenter = RecordingInstrumenter.new

    Siftly.configure do |config|
      config.use :match_filter
      config.filter(:match_filter) { |filter| filter.needle = "offer" }
      config.instrumenter = instrumenter
    end

    Siftly.check(value: "offer")

    event_names = instrumenter.events.map(&:first)

    assert_equal [
      "siftly.filter.started",
      "siftly.filter.finished",
      "siftly.pipeline.completed"
    ], event_names
  end
end
