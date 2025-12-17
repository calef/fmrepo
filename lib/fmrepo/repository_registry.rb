# frozen_string_literal: true

module FMRepo
  class RepositoryRegistry
    def initialize(config)
      @config = config
      @cache = Hash.new { |h, k| h[k] = {} } # env => { role => repo }
      @overrides = Hash.new { |h, k| h[k] = {} }
      @temp_dirs = [] # Track temporary directories for cleanup
    end

    def fetch(role:, environment:)
      env = environment.to_s
      role = role.to_sym
      return @overrides[env][role] if @overrides[env].key?(role)

      @cache[env][role] ||= build_from_config(role:, environment: env)
    end

    def with_override(role:, environment:, repo:)
      guard = install_override(role:, environment:, repo:)
      yield repo
    ensure
      guard.cleanup
    end

    def install_override(role:, environment:, repo:)
      env = environment.to_s
      role = role.to_sym
      previous_override = @overrides[env].key?(role) ? @overrides[env][role] : :__none__
      previous_cache = @cache[env].key?(role) ? @cache[env][role] : :__none__
      @overrides[env][role] = repo
      @cache[env].delete(role)
      OverrideGuard.new(self, role:, environment: env, previous_override:, previous_cache:)
    end

    def reset!
      cleanup_temp_dirs
      @cache.clear
      @overrides.clear
    end

    def cleanup_temp_dirs
      @temp_dirs.each do |dir|
        FileUtils.rm_rf(dir)
      rescue StandardError => e
        warn "Failed to cleanup temporary directory #{dir}: #{e.message}"
      end
      @temp_dirs.clear
    end

    def restore_override(role:, environment:, previous_override:, previous_cache:)
      env = environment.to_s
      role = role.to_sym
      @overrides[env].delete(role)
      @cache[env].delete(role)
      @overrides[env][role] = previous_override unless previous_override == :__none__
      @cache[env][role] = previous_cache unless previous_cache == :__none__
    end

    private

    def build_from_config(role:, environment:)
      env_map = @config.repositories[role]
      value = env_map && env_map[environment]
      raise NotBoundError, missing_repository_message(role, environment) unless value

      build_repository(value, role:, environment:)
    end

    def build_repository(value, role:, environment:)
      case value
      when FMRepo::Repository
        value
      when String, Pathname
        if temp_repo_root?(value)
          root = Dir.mktmpdir("fmrepo-#{role}-#{environment}-")
          @temp_dirs << root
        else
          root = value
        end
        FMRepo::Repository.new(root:)
      else
        raise ArgumentError,
              "repository must be a path string or Repository instance for role #{role} in #{environment}, got #{value.class}"
      end
    end

    def temp_repo_root?(value)
      value.to_s == '<tmp>'
    end

    def missing_repository_message(role, environment)
      "No repository configured for role #{role.inspect} in environment #{environment.inspect}"
    end

    class OverrideGuard
      def initialize(registry, role:, environment:, previous_override:, previous_cache:)
        @registry = registry
        @role = role
        @environment = environment
        @previous_override = previous_override
        @previous_cache = previous_cache
        @released = false
      end

      def cleanup
        return if @released

        @registry.restore_override(
          role: @role,
          environment: @environment,
          previous_override: @previous_override,
          previous_cache: @previous_cache
        )
        @released = true
      end
    end
  end
end
