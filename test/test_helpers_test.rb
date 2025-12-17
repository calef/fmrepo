# frozen_string_literal: true

require 'test_helper'

class TestHelpersTest < Minitest::Test
  class HelperModel < FMRepo::Record
    scope glob: '_items/*.md'

    naming do |front_matter:, **|
      "_items/#{FMRepo.slugify(front_matter['title'] || 'untitled')}.md"
    end
  end

  def setup
    @prev_env = FMRepo.environment
    FMRepo.environment = 'test-helpers'
    FMRepo.reset_configuration!
    @main_repo_dir = Dir.mktmpdir('fmrepo-main-')
    clear_model_cache

    FMRepo.configure do |c|
      c.repositories = {
        default: { 'test-helpers' => @main_repo_dir }
      }
    end
  end

  def teardown
    FileUtils.rm_rf(@main_repo_dir) if @main_repo_dir
    FMRepo.environment = @prev_env
    FMRepo.reset_configuration!
  end

  def test_with_temp_repo_block_yields_repo_and_cleans_up
    temp_dir = nil

    FMRepo::TestHelpers.with_temp_repo(environment: 'test-helpers') do |repo|
      temp_dir = repo.root.to_s
      HelperModel.create!({ 'title' => 'Block' }, body: 'Body')
      assert File.exist?(repo.root.join('_items', 'block.md'))
      assert Dir.exist?(temp_dir), 'temp dir should exist during block'
    end

    refute Dir.exist?(temp_dir), 'temp dir should be removed after block'

    HelperModel.create!({ 'title' => 'Main' }, body: 'Body')
    assert File.exist?(File.join(@main_repo_dir, '_items', 'main.md'))
  end

  def test_with_temp_repo_returns_override_object_and_resets_after_cleanup
    override = FMRepo::TestHelpers.with_temp_repo(environment: 'test-helpers')
    override_repo = FMRepo.repository_registry.fetch(role: :default, environment: 'test-helpers')
    override_dir = override_repo.root.to_s

    HelperModel.create!({ 'title' => 'Override' }, body: 'Body')
    assert File.exist?(File.join(override_dir, '_items', 'override.md'))

    override.cleanup
    refute Dir.exist?(override_dir), 'temp dir should be removed after manual cleanup'

    HelperModel.create!({ 'title' => 'After' }, body: 'Body')
    assert File.exist?(File.join(@main_repo_dir, '_items', 'after.md'))
  end

  private

  def clear_model_cache
    HelperModel.instance_variable_set(:@repository, nil)
    HelperModel.remove_instance_variable(:@repo_config) if HelperModel.instance_variable_defined?(:@repo_config)
  end
end
