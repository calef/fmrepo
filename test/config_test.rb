# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class ConfigTest < Minitest::Test
  def test_load_yaml_populates_repositories_and_returns_self
    file = Tempfile.new('fmrepo-config')
    file.write <<~YAML
      default:
        development: /sites/dev
        test: <tmp>
      places:
        production: /sites/live/_places
    YAML
    file.close

    config = FMRepo::Config.new
    result = config.load_yaml(file.path)

    expected = {
      default: {
        'development' => '/sites/dev',
        'test' => '<tmp>'
      },
      places: {
        'production' => '/sites/live/_places'
      }
    }

    assert_equal config, result
    assert_equal expected, config.repositories
  ensure
    file&.unlink
  end

  def test_load_yaml_preserves_existing_entries_and_ignores_missing_file
    config = FMRepo::Config.new
    config.repositories[:default] = { 'existing' => '/keep' }

    config.load_yaml('/nonexistent/file.yml')
    assert_equal({ 'existing' => '/keep' }, config.repositories[:default])
  end

  def test_load_yaml_merges_into_existing_role
    file = Tempfile.new('fmrepo-config-merge')
    file.write <<~YAML
      default:
        test: /new/test
    YAML
    file.close

    config = FMRepo::Config.new
    config.repositories[:default] = { 'development' => '/existing/dev' }

    config.load_yaml(file.path)

    assert_equal(
      { 'development' => '/existing/dev', 'test' => '/new/test' },
      config.repositories[:default]
    )
  ensure
    file&.unlink
  end
end
