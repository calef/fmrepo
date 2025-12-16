# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/calef/fmrepo/releases/tag/v0.1.0
