# frozen_string_literal: true

require "test_helper"

class ConfigTest < Minitest::Test
  def test_use_tracks_enabled_filters_once
    config = Siftly::Config.new

    config.use(:ai_topic)
    config.use("ai_topic")

    assert_equal [:ai_topic], config.enabled_filters
  end

  def test_filter_yields_mutable_filter_config
    config = Siftly::Config.new

    yielded = config.filter(:ai_topic) do |filter|
      filter.weight = 0.7
      filter.keywords = %w[ai llm]
    end

    assert_equal 0.7, yielded.weight
    assert_equal %w[ai llm], config.filter_config_for(:ai_topic).keywords
  end

  def test_dup_creates_a_deep_copy
    original = Siftly::Config.new(filter_configs: { ai_topic: { weight: 0.7 } })

    copy = original.dup
    copy.filter(:ai_topic).weight = 0.2

    assert_equal 0.7, original.filter_config_for(:ai_topic).weight
    assert_equal 0.2, copy.filter_config_for(:ai_topic).weight
  end
end

