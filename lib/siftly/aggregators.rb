# frozen_string_literal: true

module Siftly
  module Aggregators
    class Any
      def call(filter_results:, threshold:, context:)
        score = filter_results.sum(&:score)
        { spam: filter_results.any?(&:matched?), score: score }
      end
    end

    class Score
      def call(filter_results:, threshold:, context:)
        score = filter_results.sum(&:score)
        { spam: score >= threshold.to_f, score: score }
      end
    end
  end
end

