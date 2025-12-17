# frozen_string_literal: true

module FMRepo
  module Predicates
    def includes(expected)
      lambda do |value|
        case value
        when Array then value.include?(expected)
        when String then value.include?(expected.to_s)
        else false
        end
      end
    end

    def in_set(values)
      set = values.to_a
      ->(v) { set.include?(v) }
    end

    def present
      lambda do |v|
        case v
        when nil then false
        when String then !v.strip.empty?
        when Array, Hash then !v.empty?
        else true
        end
      end
    end

    def matches(regex)
      ->(v) { v.is_a?(String) && v.match?(regex) }
    end

    def gt(threshold)  = ->(value) { comparable?(value, threshold) && value >  threshold }
    def gte(threshold) = ->(value) { comparable?(value, threshold) && value >= threshold }
    def lt(threshold)  = ->(value) { comparable?(value, threshold) && value <  threshold }
    def lte(threshold) = ->(value) { comparable?(value, threshold) && value <= threshold }

    def between(lower_bound, upper_bound)
      lambda do |value|
        value &&
          comparable?(value, lower_bound) &&
          comparable?(value, upper_bound) &&
          value >= lower_bound && value <= upper_bound
      end
    end

    private

    def comparable?(value, other)
      return false unless value.respond_to?(:<=>) && other.respond_to?(:<=>)

      # Test if they're actually comparable by attempting a comparison
      true
    rescue ArgumentError, NoMethodError
      false
    end
  end

  extend Predicates
end
