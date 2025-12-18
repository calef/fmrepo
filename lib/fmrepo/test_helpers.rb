# frozen_string_literal: true

module FMRepo
  module TestHelpers
    class RepoOverride
      def initialize(guard:, tmpdir:)
        @guard = guard
        @tmpdir = tmpdir
      end

      def cleanup
        @guard.cleanup
        FileUtils.rm_rf(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
      end
    end

    def self.with_temp_repo(role: :default, environment: nil)
      env = (environment || FMRepo.environment).to_s
      tmpdir = Dir.mktmpdir("fmrepo-#{role}-#{env}-")
      repo = FMRepo::Repository.new(root: tmpdir)
      registry = FMRepo.repository_registry

      if block_given?
        registry.with_override(role:, environment: env, repo:) do
          yield repo
        ensure
          FileUtils.rm_rf(tmpdir) if tmpdir && Dir.exist?(tmpdir)
        end
      else
        guard = registry.install_override(role:, environment: env, repo:)
        RepoOverride.new(guard:, tmpdir:)
      end
    end
  end
end
