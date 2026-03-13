# frozen_string_literal: true

require "test_helper"

class RegistryTest < Minitest::Test
  class TestFilter < Siftly::Filter
    register_as :test_filter

    def call(value:, attribute: nil, record: nil, context: {})
      result(matched: !value.to_s.empty?, score: 1.0)
    end
  end

  def test_register_and_resolve_filter
    Siftly::Registry.register(TestFilter, metadata: { category: :keyword })

    assert_equal [:test_filter], Siftly::Registry.available
    assert_equal TestFilter, Siftly::Registry.resolve(:test_filter)
    assert_equal({ category: :keyword }, Siftly::Registry.metadata_for(:test_filter))
  end

  def test_duplicate_registration_raises
    Siftly::Registry.register(TestFilter)

    error = assert_raises(Siftly::DuplicateFilterError) do
      Siftly::Registry.register(TestFilter)
    end

    assert_match(/test_filter/, error.message)
  end

  def test_unregistered_filter_raises
    assert_raises(Siftly::UnknownFilterError) do
      Siftly::Registry.resolve(:missing)
    end
  end
end

