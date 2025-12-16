# frozen_string_literal: true

require_relative 'lib/fmrepo/version'

Gem::Specification.new do |spec|
  spec.name = 'fmrepo'
  spec.version = FMRepo::VERSION
  spec.authors = ['FMRepo Contributors']
  spec.email = ['chris@crickertech.com']

  spec.summary = 'Active Record-style ORM for front-matter Markdown files'
  spec.description = <<~DESCRIPTION
    FMRepo provides an Active Record-like interface for managing Markdown files with YAML front matter in static site repositories.
    Perfect for Jekyll-style collections and custom static site generators.
  DESCRIPTION
  spec.homepage = 'https://github.com/calef/fmrepo'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.4.7'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/calef/fmrepo'
  spec.metadata['changelog_uri'] = 'https://github.com/calef/fmrepo/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob('{lib}/**/*') + %w[LICENSE README.md]
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
