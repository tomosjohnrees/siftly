# frozen_string_literal: true

require "test_helper"

class FilterConfigTest < Minitest::Test
  def test_dynamic_readers_and_writers_store_symbol_keys
    config = Siftly::FilterConfig.new(:ai_topic)

    config.weight = 0.7
    config.keywords = %w[ai llm]

    assert_equal 0.7, config[:weight]
    assert_equal %w[ai llm], config.keywords
  end

  def test_merge_returns_a_new_config
    config = Siftly::FilterConfig.new(:ai_topic, weight: 0.7)

    merged = config.merge("weight" => 0.5, "locale" => "en")

    assert_equal 0.7, config.weight
    assert_equal 0.5, merged.weight
    assert_equal "en", merged.locale
  end
end

