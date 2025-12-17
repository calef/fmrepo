# frozen_string_literal: true

require 'test_helper'

class EnvironmentResolutionTest < Minitest::Test
  def setup
    @prev_env_var = {
      'FMREPO_ENV' => ENV.fetch('FMREPO_ENV', nil),
      'JEKYLL_ENV' => ENV.fetch('JEKYLL_ENV', nil),
      'RACK_ENV' => ENV.fetch('RACK_ENV', nil),
      'RAILS_ENV' => ENV.fetch('RAILS_ENV', nil)
    }
    FMRepo.environment = nil
  end

  def teardown
    restore_env(@prev_env_var)
    FMRepo.environment = nil
  end

  def test_prefers_fmrepo_env_then_jekyll_env
    ENV['FMREPO_ENV'] = 'fmrepo-env'
    ENV['JEKYLL_ENV'] = 'jekyll-env'

    assert_equal 'fmrepo-env', FMRepo.environment

    FMRepo.environment = nil
    ENV.delete('FMREPO_ENV')
    assert_equal 'jekyll-env', FMRepo.environment
  end

  def test_prefers_jekyll_env_over_rack_env
    ENV.delete('FMREPO_ENV')
    ENV['JEKYLL_ENV'] = 'jekyll-env'
    ENV['RACK_ENV'] = 'rack-env'

    assert_equal 'jekyll-env', FMRepo.environment
  end

  private

  def restore_env(snapshot)
    snapshot.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
