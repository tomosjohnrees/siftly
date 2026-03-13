# frozen_string_literal: true

module Siftly
  class Filter
    class << self
      attr_reader :key

      def register_as(key)
        @key = key.to_sym
      end
    end

    def initialize(config: {})
      @config =
        case config
        when FilterConfig
          config.merge({})
        when Hash
          FilterConfig.new(self.class.key || :unknown, config)
        else
          raise ConfigurationError, "filter config must be a Hash or FilterConfig"
        end
    end

    def call(value:, attribute: nil, record: nil, context: {})
      raise NotImplementedError, "#{self.class} must implement #call"
    end

    private

    attr_reader :config

    def result(matched:, score: 0.0, reason: nil, metadata: {}, error: nil)
      FilterResult.new(
        filter: self.class.key,
        matched: matched,
        score: score,
        reason: reason,
        metadata: metadata,
        error: error
      )
    end
  end
end

