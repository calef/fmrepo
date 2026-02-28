# frozen_string_literal: true

module FMRepo
  class Config
    attr_accessor :repositories

    def initialize
      @repositories = {}
    end

    def load_yaml(path)
      return self unless File.exist?(path)

      begin
        data = YAML.safe_load_file(path, aliases: false) || {}
      rescue Psych::SyntaxError => e
        raise "Failed to parse YAML configuration file #{path}: #{e.message}"
      end
      data.each do |role, env_map|
        role_key = role.to_sym
        unless env_map.is_a?(Hash)
          raise ArgumentError,
                "Expected a Hash of environment => path for role #{role.inspect} in #{path}, got #{env_map.class}"
        end
        repositories[role_key] ||= {}
        env_map.each do |env, value|
          repositories[role_key][env.to_s] = value
        end
      end
      self
    end
  end
end
