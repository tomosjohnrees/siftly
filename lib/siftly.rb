# frozen_string_literal: true

require_relative "siftly/version"
require_relative "siftly/errors"
require_relative "siftly/filter_config"
require_relative "siftly/config"
require_relative "siftly/filter"
require_relative "siftly/filter_result"
require_relative "siftly/result"
require_relative "siftly/registry"
require_relative "siftly/instrumentation"
require_relative "siftly/aggregators"
require_relative "siftly/pipeline"
require_relative "siftly/checker"

module Siftly
  class << self
    def configure
      yield(config)
      config
    end

    def config
      @config ||= Config.new
    end

    def check(**options)
      Checker.new(config: config).call(**options)
    end

    def reset_configuration!
      @config = Config.new
    end
  end
end
