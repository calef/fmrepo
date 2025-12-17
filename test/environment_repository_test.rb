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
end
