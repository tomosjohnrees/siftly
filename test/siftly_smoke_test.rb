# frozen_string_literal: true

require "test_helper"

class SiftlySmokeTest < Minitest::Test
  def test_has_a_version_number
    refute_nil Siftly::VERSION
  end
end
