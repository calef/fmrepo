# frozen_string_literal: true

module FMRepo
  class Error < StandardError; end
  class NotBoundError < Error; end
  class NotFound < Error; end
  class UnsafePathError < Error; end
  class ParseError < Error; end
end
