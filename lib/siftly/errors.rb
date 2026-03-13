# frozen_string_literal: true

module Siftly
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class InvalidFilterError < Error; end
  class DuplicateFilterError < Error; end
  class UnknownFilterError < Error; end
  class InvalidAggregatorError < Error; end
end

