# frozen_string_literal: true

module Siftly
  class Registry
    class << self
      def register(filter_class, replace: false, metadata: {})
        validate_filter_class!(filter_class)

        key = filter_class.key
        raise DuplicateFilterError, "filter #{key.inspect} is already registered" if !replace && filters.key?(key)

        filters[key] = { klass: filter_class, metadata: metadata.dup.freeze }
        filter_class
      end

      def fetch(key)
        filters.fetch(key.to_sym) { raise UnknownFilterError, "unknown filter #{key.inspect}" }
      end

      def resolve(key)
        fetch(key).fetch(:klass)
      end

      def metadata_for(key)
        fetch(key).fetch(:metadata)
      end

      def available
        filters.keys.sort
      end

      def registered?(key)
        filters.key?(key.to_sym)
      end

      def clear
        @filters = {}
      end

      private

      def filters
        @filters ||= {}
      end

      def validate_filter_class!(filter_class)
        raise InvalidFilterError, "registered filters must inherit from Siftly::Filter" unless filter_class < Filter
        raise InvalidFilterError, "registered filters must call register_as" if filter_class.key.nil?
      end
    end
  end
end

