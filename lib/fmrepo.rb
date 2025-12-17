# frozen_string_literal: true

require 'yaml'
require 'pathname'
require 'fileutils'
require 'securerandom'
require 'date'
require 'time'
require 'tmpdir'

require_relative 'fmrepo/version'
require_relative 'fmrepo/errors'
require_relative 'fmrepo/config'
require_relative 'fmrepo/model_config'
require_relative 'fmrepo/repository'
require_relative 'fmrepo/repository_registry'
require_relative 'fmrepo/predicates'
require_relative 'fmrepo/record'
require_relative 'fmrepo/relation'
require_relative 'fmrepo/test_helpers'

module FMRepo
  def self.environment
    @environment ||= ENV['FMREPO_ENV'] || ENV['JEKYLL_ENV'] || ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
  end

  def self.environment=(env)
    @environment = env&.to_s
  end

  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield config
    repository_registry.reset!
  end

  def self.repository_registry
    @repository_registry ||= RepositoryRegistry.new(config)
  end

  def self.reset_configuration!
    @config = Config.new
    load_default_config_file
    @repository_registry = RepositoryRegistry.new(config)
  end

  def self.load_default_config_file
    default_path = File.expand_path('.fmrepo.yml')
    config.load_yaml(default_path) if File.exist?(default_path)
  end

  def self.slugify(str)
    s = str.to_s.strip.downcase
    s = s.gsub(/['"]/, '')
    s = s.gsub(/[^a-z0-9]+/, '-')
    # Remove leading/trailing dashes by chomping instead of regex
    s = s[1..] while s.start_with?('-')
    s = s[0..-2] while s.end_with?('-')
    s.empty? ? 'untitled' : s
  end
end
