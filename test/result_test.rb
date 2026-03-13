# frozen_string_literal: true

require "test_helper"

class ResultTest < Minitest::Test
  def test_matches_and_errors_are_derived_from_filter_results
    matched = Siftly::FilterResult.new(filter: :ai_topic, matched: true, score: 0.7, reason: "match")
    errored = Siftly::FilterResult.new(filter: :links, matched: false, score: 0.0, error: "boom")

    result = Siftly::Result.new(
      spam: true,
      score: 0.7,
      filter_results: [matched, errored],
      reasons: [matched.reason],
      attribute: :message,
      value_preview: "text",
      threshold: 0.5,
      aggregator: :score
    )

    assert_equal [matched], result.matches
    assert_equal [errored], result.errors
    assert result.spam?
  end
end
