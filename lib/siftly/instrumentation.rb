# frozen_string_literal: true

module Siftly
  module Instrumentation
    class NullInstrumenter
      def instrument(_event, payload = {})
        yield(payload) if block_given?
      end
    end
  end
end

