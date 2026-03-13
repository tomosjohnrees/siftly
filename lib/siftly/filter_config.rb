# frozen_string_literal: true

module Siftly
  class FilterConfig
    attr_reader :key

    def initialize(key, settings = {})
      @key = key.to_sym
      @settings = symbolize_keys(settings)
    end

    def [](name)
      @settings[name.to_sym]
    end

    def fetch(name, *fallback)
      @settings.fetch(name.to_sym, *fallback)
    end

    def to_h
      @settings.dup
    end

    def merge(overrides)
      self.class.new(key, @settings.merge(symbolize_keys(overrides)))
    end

    def method_missing(method_name, *arguments, &block)
      return super if block

      method = method_name.to_s

      if method.end_with?("=")
        @settings[method.delete_suffix("=").to_sym] = arguments.fetch(0)
      elsif arguments.empty?
        @settings[method_name]
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      method_name.to_s.end_with?("=") || @settings.key?(method_name.to_sym) || super
    end

    private

    def symbolize_keys(hash)
      hash.each_with_object({}) do |(key, value), result|
        result[key.to_sym] = value
      end
    end
  end
end

