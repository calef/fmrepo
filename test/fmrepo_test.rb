# frozen_string_literal: true

require 'test_helper'

class FMRepoTest < Minitest::Test
  class DefaultModel < FMRepo::Record
    scope glob: '_items/*.md'

    naming do |front_matter:, **|
      "_items/#{FMRepo.slugify(front_matter['title'] || 'untitled')}.md"
    end
  end

  def setup
    @prev_env = FMRepo.environment
    FMRepo.environment = 'development'
    FMRepo.reset_configuration!
  end

  def teardown
    FMRepo.environment = @prev_env
    FMRepo.reset_configuration!
  end

  def test_reset_configuration_loads_default_config_without_deadlock
    Dir.mktmpdir('fmrepo-default-config-') do |dir|
      Dir.chdir(dir) do
        File.write('.fmrepo.yml', <<~YAML)
          default:
            development: /repos/from-default
        YAML

        FMRepo.reset_configuration!

        assert_equal(
          '/repos/from-default',
          FMRepo.config.repositories.dig(:default, 'development')
        )
      end
    end
  end

  def test_default_config_file_auto_loads_for_repository_registry
    dir = Dir.mktmpdir('fmrepo-auto-default-')
    Dir.chdir(dir) do
      File.write('.fmrepo.yml', <<~YAML)
        default:
          development: #{dir}/site
      YAML

      FMRepo.reset_configuration!
      clear_model_cache(DefaultModel)

      DefaultModel.create!({ 'title' => 'Auto' }, body: 'Body')

      assert File.exist?(File.join(dir, 'site', '_items', 'auto.md'))
    end
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_repository_registry_shares_config_with_config_object
    FMRepo.repository_registry # force initialization before configuration

    repo_root = Dir.mktmpdir('fmrepo-shared-config-')
    FMRepo.configure do |c|
      c.repositories = { default: { 'development' => repo_root } }
    end

    repo = FMRepo.repository_registry.fetch(role: :default, environment: 'development')
    assert_equal repo_root, repo.root.to_s
  ensure
    FileUtils.rm_rf(repo_root) if repo_root
  end

  private

  def clear_model_cache(klass)
    klass.instance_variable_set(:@repository, nil)
    klass.remove_instance_variable(:@repo_config) if klass.instance_variable_defined?(:@repo_config)
  end
end
