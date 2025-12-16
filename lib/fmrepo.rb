# frozen_string_literal: true

require "yaml"
require "pathname"
require "fileutils"
require "securerandom"
require "date"
require "time"

require_relative "fmrepo/version"
require_relative "fmrepo/errors"
require_relative "fmrepo/model_config"
require_relative "fmrepo/repository"
require_relative "fmrepo/predicates"
require_relative "fmrepo/record"
require_relative "fmrepo/relation"

module FMRepo
  def self.slugify(str)
    s = str.to_s.strip.downcase
    s = s.gsub(/['"]/,"")
    s = s.gsub(/[^a-z0-9]+/, "-")
    s = s.gsub(/\A-+|-+\z/, "")
    s.empty? ? "untitled" : s
  end
end
