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
  @environment_mutex = Mutex.new
  @config_mutex = Mutex.new
  @repository_registry_mutex = Mutex.new

  def self.environment
    @environment_mutex.synchronize do
      @environment ||= ENV['FMREPO_ENV'] || ENV['JEKYLL_ENV'] || ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
    end
  end

  def self.environment=(env)
    @environment_mutex.synchronize do
      @environment = env&.to_s
    end
  end

  def self.config
    @config_mutex.synchronize do
      @config ||= Config.new
    end
  end

  def self.configure
    cfg = nil
    @config_mutex.synchronize do
      cfg = @config ||= Config.new
    end
    yield cfg
    @repository_registry_mutex.synchronize do
      @repository_registry&.reset!
    end
  end

  def self.repository_registry
    @repository_registry_mutex.synchronize do
      @repository_registry ||= begin
        cfg = nil
        @config_mutex.synchronize do
          cfg = @config ||= Config.new
        end
        RepositoryRegistry.new(cfg)
      end
    end
  end

  def self.reset_configuration!
    cfg = nil
    @config_mutex.synchronize do
      @config = Config.new
      cfg = @config
      load_default_config_file
    end
    @repository_registry_mutex.synchronize do
      @repository_registry = RepositoryRegistry.new(cfg)
    end
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
