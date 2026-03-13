# frozen_string_literal: true

module Siftly
  class FilterResult
    attr_reader :filter, :score, :reason, :metadata, :error, :duration_ms

    def initialize(filter:, matched:, score:, reason: nil, metadata: {}, error: nil, duration_ms: nil)
      @filter = filter.to_sym
      @matched = matched
      @score = score.to_f
      @reason = reason
      @metadata = metadata.dup
      @error = error
      @duration_ms = duration_ms
    end

    def matched?
      @matched
    end

    def error?
      !error.nil?
    end

    def with(
      filter: @filter,
      matched: @matched,
      score: @score,
      reason: @reason,
      metadata: @metadata,
      error: @error,
      duration_ms: @duration_ms
    )
      self.class.new(
        filter: filter,
        matched: matched,
        score: score,
        reason: reason,
        metadata: metadata,
        error: error,
        duration_ms: duration_ms
      )
    end
  end
end
