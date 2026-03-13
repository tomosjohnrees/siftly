# frozen_string_literal: true

module Siftly
  class Result
    attr_reader :score, :filter_results, :reasons, :attribute, :value_preview, :threshold, :aggregator

    def initialize(spam:, score:, filter_results:, reasons:, attribute:, value_preview:, threshold:, aggregator:)
      @spam = spam
      @score = score.to_f
      @filter_results = filter_results.dup.freeze
      @reasons = reasons.compact.freeze
      @attribute = attribute
      @value_preview = value_preview
      @threshold = threshold
      @aggregator = aggregator
    end

    def spam?
      @spam
    end

    def matches
      filter_results.select(&:matched?)
    end

    def errors
      filter_results.select(&:error?)
    end
  end
end

