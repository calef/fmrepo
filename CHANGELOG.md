# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.10] - 2026-01-24

### Added

- `Record.scope_config` class method providing a public API for accessing scope configuration.
  - Returns a hash with `:glob`, `:exclude`, and `:extensions` keys.
  - Consumers should use this method instead of introspecting private instance variables.

## [0.2.9] - 2026-01-22

### Added

- Convention over configuration: test environment automatically uses isolated temp directories when no repository is configured.
- Role fallback: custom roles (e.g., `:places`) now fall back to `:default` role configuration if not explicitly configured.

### Changed

- Test environment no longer falls back to development configuration; it uses auto-generated temp directories instead.
- Simplified error messages for missing repository configuration.

## [0.2.8] - 2026-01-08

### Added

- `belongs_to` now creates `{name}_id` and `{name}_id=` methods for direct foreign key access.
  - Setting `{name}_id=` clears the cached association so the new associated record is loaded on next access.

## [0.2.7] - 2026-01-08

### Added

- `belongs_to` association DSL for defining model relationships via front matter foreign keys.
  - Stores foreign key as `{name}_id` in front matter.
  - Lazy-loads associated record with caching.
  - Provides setter method to update both association and foreign key.
  - Returns `nil` for missing records.
- `has_many` association DSL for defining one-to-many relationships.
  - Returns chainable `Relation` filtered by `{model_name}_id` foreign key.
  - Simple pluralization (strips trailing 's').
  - Returns empty chainable `Relation` for unpersisted records.
- Namespace-aware association resolution (tries global scope, then local namespace).

## [0.2.6] - 2026-01-06

### Changed

- Update dependencies.

## [0.2.5] - 2025-12-29

### Changed

- Convert ampersands to the word `and` before slug normalization so titles such as `Rock & Roll`
  produce `rock-and-roll`.

## [0.2.4] - 2025-12-27

### Changed

- Update required Ruby version to 3.4.8.

## [0.2.3] - 2025-12-17

### Fixed

- Automatically load `.fmrepo.yml` on first use and ensure the repository registry shares the global configuration so
  environment defaults apply without per-class repository configuration.

## [0.2.2] - 2025-12-17

### Changed

- Front matter keys are now sorted alphabetically when serializing records to minimize diff sizes in version control.

## [0.2.1] - 2025-12-17

### Fixed

- Prevent deadlock in `FMRepo.reset_configuration!` by loading the default config file outside the mutex.

## [0.2.0] - 2025-12-17

### Added

- Environment-driven repository resolution with role support and optional `.fmrepo.yml` configuration.
- Test helpers for temporary repository overrides (`FMRepo::TestHelpers.with_temp_repo`).
- Environment precedence now checks `FMREPO_ENV`, then `JEKYLL_ENV`, `RACK_ENV`, `RAILS_ENV`.

### Changed

- Models can declare `repository_role` and fall back to environment-driven repositories; explicit `repository` calls still
  override per class.
- Default repository config file location is `.fmrepo.yml` at project root.

## [0.1.1] - 2025-12-16

### Changed

- Bump dependencies: rake 13.3.1, ostruct 0.6.3, minitest 5.27.0, mutex_m 0.3.0

## [0.1.0] - 2025-12-15

### Added

- Initial release of FMRepo gem
- Active Record-style API for front-matter Markdown files
- `FMRepo::Repository` class for safe filesystem operations
- `FMRepo::Record` base class for models
- `FMRepo::Relation` for chainable queries
- Pattern A binding (class-level repository binding)
- Query predicates: `includes`, `in_set`, `present`, `matches`, `gt`, `gte`, `lt`, `lte`, `between`
- Reserved query fields: `_id`, `_path`, `_rel_path`, `_mtime`, `_model`
- Custom naming rules for new records
- Automatic collision resolution
- Atomic file writes
- Path safety validation
- Front matter parsing with YAML support
- Class methods: `all`, `where`, `order`, `limit`, `offset`, `find`, `find_by`, `create!`
- Instance methods: `save!`, `destroy`, `reload`, `[]`, `[]=`, `body`, `id`, `persisted?`, `new_record?`
- Custom relation classes for domain-specific query methods
- Comprehensive test suite (56 tests)
- Documentation and examples

[0.2.10]: https://github.com/calef/fmrepo/releases/tag/v0.2.10
[0.2.9]: https://github.com/calef/fmrepo/releases/tag/v0.2.9
[0.2.8]: https://github.com/calef/fmrepo/releases/tag/v0.2.8
[0.2.7]: https://github.com/calef/fmrepo/releases/tag/v0.2.7
[0.2.6]: https://github.com/calef/fmrepo/releases/tag/v0.2.6
[0.2.5]: https://github.com/calef/fmrepo/releases/tag/v0.2.5
[0.2.4]: https://github.com/calef/fmrepo/releases/tag/v0.2.4
[0.2.3]: https://github.com/calef/fmrepo/releases/tag/v0.2.3
[0.2.2]: https://github.com/calef/fmrepo/releases/tag/v0.2.2
[0.2.1]: https://github.com/calef/fmrepo/releases/tag/v0.2.1
[0.2.0]: https://github.com/calef/fmrepo/releases/tag/v0.2.0
[0.1.1]: https://github.com/calef/fmrepo/releases/tag/v0.1.1
[0.1.0]: https://github.com/calef/fmrepo/releases/tag/v0.1.0
