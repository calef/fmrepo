# frozen_string_literal: true

require 'test_helper'

class EnvironmentRepositoryTest < Minitest::Test
  class EnvModel < FMRepo::Record
    scope glob: '_items/*.md'

    naming do |front_matter:, **|
      "_items/#{FMRepo.slugify(front_matter['title'] || 'untitled')}.md"
    end
  end

  def setup
    @prev_env = FMRepo.environment
    FMRepo.environment = 'env-test'
    FMRepo.reset_configuration!
    @tmpdir = Dir.mktmpdir
    EnvModel.instance_variable_set(:@repository, nil)
    EnvModel.remove_instance_variable(:@repo_config) if EnvModel.instance_variable_defined?(:@repo_config)

    FMRepo.configure do |c|
      c.repositories = {
        default: { 'env-test' => @tmpdir }
      }
    end
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir
    FMRepo.environment = @prev_env
    FMRepo.reset_configuration!
  end

  def test_environment_repository_is_used_when_not_explicitly_bound
    EnvModel.create!({ 'title' => 'Hello' }, body: 'Body')
    assert File.exist?(File.join(@tmpdir, '_items', 'hello.md'))
  end

  def test_repository_override_still_allowed
    other_dir = Dir.mktmpdir
    EnvModel.repository(other_dir)

    EnvModel.create!({ 'title' => 'Other' }, body: 'Body')
    assert File.exist?(File.join(other_dir, '_items', 'other.md'))
  ensure
    FileUtils.rm_rf(other_dir) if other_dir
  end

  def test_test_helper_overrides_repo_temporarily
    FMRepo::TestHelpers.with_temp_repo(environment: 'env-test') do |repo|
      EnvModel.create!({ 'title' => 'Temp' }, body: 'Body')
      assert File.exist?(repo.root.join('_items', 'temp.md'))
    end

    # After helper, default repo should be used again
    EnvModel.create!({ 'title' => 'DefaultBack' }, body: 'Body')
    assert File.exist?(File.join(@tmpdir, '_items', 'defaultback.md'))
  end

  def test_raises_not_bound_error_when_repository_not_configured
    FMRepo.reset_configuration!
    FMRepo.environment = 'unconfigured-env'
    EnvModel.instance_variable_set(:@repository, nil)
    EnvModel.remove_instance_variable(:@repo_config) if EnvModel.instance_variable_defined?(:@repo_config)

    error = assert_raises(FMRepo::NotBoundError) do
      EnvModel.create!({ 'title' => 'Test' }, body: 'Body')
    end

    assert_match(/No repository configured for role :default in environment "unconfigured-env"/, error.message)
  end

  def test_non_test_environment_falls_back_to_development_when_value_is_nil
    dev_dir = Dir.mktmpdir
    FMRepo.reset_configuration!
    EnvModel.instance_variable_set(:@repository, nil)
    EnvModel.remove_instance_variable(:@repo_config) if EnvModel.instance_variable_defined?(:@repo_config)

    FMRepo.configure do |c|
      c.repositories = {
        default: { 'development' => dev_dir, 'staging' => nil }
      }
    end

    FMRepo.environment = 'staging'
    EnvModel.create!({ 'title' => 'Fallback' }, body: 'Body')
    assert File.exist?(File.join(dev_dir, '_items', 'fallback.md'))
  ensure
    FileUtils.rm_rf(dev_dir) if dev_dir
  end

  def test_non_test_environment_falls_back_to_development_from_yaml_config
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        File.write('.fmrepo.yml', <<~YAML)
          default:
            development: "#{tmpdir}"
            staging: ~
        YAML

        FMRepo.reset_configuration!
        FMRepo.environment = 'staging'
        EnvModel.instance_variable_set(:@repository, nil)
        EnvModel.remove_instance_variable(:@repo_config) if EnvModel.instance_variable_defined?(:@repo_config)

        EnvModel.create!({ 'title' => 'YamlFallback' }, body: 'Body')
        assert File.exist?(File.join(tmpdir, '_items', 'yamlfallback.md'))
      end
    end
  end

  def test_development_environment_with_nil_value_raises_error
    FMRepo.reset_configuration!
    EnvModel.instance_variable_set(:@repository, nil)
    EnvModel.remove_instance_variable(:@repo_config) if EnvModel.instance_variable_defined?(:@repo_config)

    FMRepo.configure do |c|
      c.repositories = {
        default: { 'development' => nil }
      }
    end

    FMRepo.environment = 'development'
    error = assert_raises(FMRepo::NotBoundError) do
      EnvModel.create!({ 'title' => 'Test' }, body: 'Body')
    end

    assert_match(/No repository configured for role :default in environment "development"/, error.message)
    refute_match(/fallback/, error.message)
  end

  def test_test_environment_auto_uses_temp_dir_when_not_configured
    FMRepo.reset_configuration!
    EnvModel.instance_variable_set(:@repository, nil)
    EnvModel.remove_instance_variable(:@repo_config) if EnvModel.instance_variable_defined?(:@repo_config)

    # No configuration at all
    FMRepo.environment = 'test'
    EnvModel.create!({ 'title' => 'AutoTemp' }, body: 'Body')

    # Should have created in a temp directory
    repo = FMRepo.repository_registry.fetch(role: :default, environment: 'test')
    assert repo.root.to_s.start_with?(Dir.tmpdir), "Expected repo root to be in temp dir, got: #{repo.root}"
  end

  def test_test_environment_auto_temp_even_with_nil_config
    FMRepo.reset_configuration!
    EnvModel.instance_variable_set(:@repository, nil)
    EnvModel.remove_instance_variable(:@repo_config) if EnvModel.instance_variable_defined?(:@repo_config)

    FMRepo.configure do |c|
      c.repositories = {
        default: { 'development' => '/some/path', 'test' => nil }
      }
    end

    FMRepo.environment = 'test'
    repo = FMRepo.repository_registry.fetch(role: :default, environment: 'test')
    assert repo.root.to_s.start_with?(Dir.tmpdir), "Expected repo root to be in temp dir, got: #{repo.root}"
  end

  def test_custom_role_falls_back_to_default_config
    dev_dir = Dir.mktmpdir
    FMRepo.reset_configuration!

    FMRepo.configure do |c|
      c.repositories = {
        default: { 'development' => dev_dir }
      }
    end

    FMRepo.environment = 'development'
    # Fetch a role that doesn't exist - should fall back to :default
    repo = FMRepo.repository_registry.fetch(role: :custom_role, environment: 'development')
    assert_equal dev_dir, repo.root.to_s
  ensure
    FileUtils.rm_rf(dev_dir) if dev_dir
  end

  def test_custom_role_uses_explicit_config_over_default
    dev_dir = Dir.mktmpdir
    custom_dir = Dir.mktmpdir
    FMRepo.reset_configuration!

    FMRepo.configure do |c|
      c.repositories = {
        default: { 'development' => dev_dir },
        custom_role: { 'development' => custom_dir }
      }
    end

    FMRepo.environment = 'development'
    repo = FMRepo.repository_registry.fetch(role: :custom_role, environment: 'development')
    assert_equal custom_dir, repo.root.to_s
  ensure
    FileUtils.rm_rf(dev_dir) if dev_dir
    FileUtils.rm_rf(custom_dir) if custom_dir
  end
end
