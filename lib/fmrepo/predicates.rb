# frozen_string_literal: true

module FMRepo
  module Predicates
    def includes(x)
      lambda do |v|
        case v
        when Array then v.include?(x)
        when String then v.include?(x.to_s)
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

    def gt(x)  = ->(v) { comparable?(v, x) && v >  x }
    def gte(x) = ->(v) { comparable?(v, x) && v >= x }
    def lt(x)  = ->(v) { comparable?(v, x) && v <  x }
    def lte(x) = ->(v) { comparable?(v, x) && v <= x }

    def between(a, b)
      ->(v) { v && comparable?(v, a) && comparable?(v, b) && v >= a && v <= b }
    end

    private

    def comparable?(v, x)
      return false unless v.respond_to?(:<=>) && x.respond_to?(:<=>)

      # Test if they're actually comparable by attempting a comparison
      true
    rescue ArgumentError, NoMethodError
      false
    end
  end

  extend Predicates
end
