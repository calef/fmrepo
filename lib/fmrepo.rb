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
  @mutex = Mutex.new

  def self.environment
    @mutex.synchronize do
      @environment ||= ENV['FMREPO_ENV'] || ENV['JEKYLL_ENV'] || ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
    end
  end

  def self.environment=(env)
    @mutex.synchronize do
      @environment = env&.to_s
    end
  end

  def self.config
    @mutex.synchronize do
      ensure_config!
    end
  end

  def self.configure
    @mutex.synchronize do
      cfg = ensure_config!
      @mutex.unlock
      begin
        yield cfg
      ensure
        @mutex.lock
      end
      @repository_registry&.reset!
    end
  end

  def self.repository_registry
    @mutex.synchronize do
      cfg = ensure_config!
      @repository_registry ||= RepositoryRegistry.new(cfg)
    end
  end

  def self.reset_configuration!
    new_config = Config.new
    default_loaded = load_default_config_into(new_config) ? :loaded : :not_found
    new_registry = RepositoryRegistry.new(new_config)

    @mutex.synchronize do
      @config = new_config
      @repository_registry = new_registry
      @default_config_loaded = default_loaded
    end
  end

  def self.load_default_config_file
    @mutex.synchronize do
      cfg = ensure_config!(load_default: false)
      loaded = load_default_config_into(cfg)
      @default_config_loaded ||= (loaded ? :loaded : :not_found)
    end
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

  class << self
    private

    def ensure_config!(load_default: true)
      @config ||= Config.new
      load_default_config_if_needed if load_default
      @config
    end

    def load_default_config_if_needed
      return if @default_config_loaded

      @default_config_loaded = load_default_config_into(@config) ? :loaded : :not_found
    end

    def load_default_config_into(config)
      default_path = default_config_path
      return false unless File.exist?(default_path)

      config.load_yaml(default_path)
      true
    end

    def default_config_path
      File.expand_path('.fmrepo.yml')
    end
  end
end
