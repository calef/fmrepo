# frozen_string_literal: true

module FMRepo
  class RepositoryRegistry
    def initialize(config)
      @config = config
      @cache = Hash.new { |h, k| h[k] = {} } # env => { role => repo }
      @overrides = Hash.new { |h, k| h[k] = {} }
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
      @cache.clear
      @overrides.clear
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
        root = temp_repo_root?(value) ? Dir.mktmpdir("fmrepo-#{role}-#{environment}-") : value
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

        @registry.instance_exec(@role, @environment, @previous_override,
                                @previous_cache) do |role, environment, previous_override, previous_cache|
          @overrides[environment].delete(role)
          @cache[environment].delete(role)
          @overrides[environment][role] = previous_override unless previous_override == :__none__
          @cache[environment][role] = previous_cache unless previous_cache == :__none__
        end
        @released = true
      end
    end
  end
end
