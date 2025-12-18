# frozen_string_literal: true

require 'test_helper'

class FMRepoTest < Minitest::Test
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
end
