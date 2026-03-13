# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "minitest/autorun"
require "siftly"

class Minitest::Test
  def setup
    super
    Siftly.reset_configuration!
    Siftly::Registry.clear
  end
end
