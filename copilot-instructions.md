# GitHub Copilot Instructions for FMRepo

## Project Overview

FMRepo is a Ruby gem that provides an Active Record-style ORM for managing Markdown files with YAML front matter in
static site repositories. Think Jekyll collections with a familiar query interface.

## Key Concepts

- **Repository**: `FMRepo::Repository` handles all filesystem operations with path safety and atomic writes
- **Record**: `FMRepo::Record` is the base class for models, each representing a Markdown file with front matter
- **Relation**: `FMRepo::Relation` provides chainable query interface (where, order, limit, etc.)
- **Predicates**: Custom query predicates for filtering (includes, matches, gt, lt, etc.)

## Project Structure

```text
lib/
  fmrepo.rb          # Main entry point, loads all components
  fmrepo/
    errors.rb        # Custom error classes
    repository.rb    # Filesystem operations, path safety, atomic writes
    record.rb        # Base model class with DSL
    relation.rb      # Chainable query interface
    predicates.rb    # Query predicate functions
    model_config.rb  # Model configuration storage
    version.rb       # Gem version constant

test/
  test_helper.rb     # Test setup and load path configuration
  repository_test.rb # Repository filesystem operation tests
  record_test.rb     # Record model and query tests
  integration_test.rb # End-to-end integration tests

examples/
  basic_usage.rb     # Minimal usage demonstration

script/
  bootstrap          # Setup development environment
  test               # Run linter + full test suite
  cibuild            # CI build script
  ensure-*           # Tool installation scripts
```

## Coding Conventions

### Ruby Style

- Use 2-space indentation
- Add `# frozen_string_literal: true` to all Ruby files
- Prefer small, focused classes over large monolithic ones
- Use explicit keyword arguments in method signatures
- Follow Ruby naming: `snake_case.rb` files, `CamelCase` classes/modules

### Design Patterns

- Wrap all filesystem operations in `FMRepo::Repository` - never use `File` directly
- Use immutable relation objects for queries (return new instances, don't modify)
- Predicates should be callable objects (procs/lambdas) for flexibility
- Model classes configure via class-level DSL methods (`repository`, `scope`, `naming`)

### Example Code Style

```ruby
# Good: Explicit keyword arguments
def create_record(front_matter:, body:, path: nil)
  # ...
end

# Good: Chainable, immutable relations
Post.where("published" => true).order("date", :desc).limit(10)

# Good: Repository wrapping file operations
repo.write_file(path, content)

# Bad: Direct file operations
File.write(path, content)
```

## Testing Approach

### Test Structure

- Use Minitest (not RSpec)
- Inherit from `Minitest::Test`
- Mirror runtime structure: `lib/fmrepo/foo.rb` → `test/foo_test.rb`
- Use temporary directories via `Dir.mktmpdir` for filesystem tests
- Create inline fixtures rather than committing sample files

### Test Coverage Requirements

- Test both success and failure paths
- Cover path validation and safety checks
- Test collision resolution in file naming
- Verify atomic write behavior
- Test predicate matching logic

### Example Test Pattern

```ruby
class RecordTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @repo = FMRepo::Repository.new(root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_something
    # Arrange
    # Act
    # Assert
  end
end
```

## Development Workflow

### Setup

```bash
./script/bootstrap  # Install Ruby 3.4.7, Bundler 4.0.2, and gems
```

### Running Tests

```bash
./script/test            # Run RuboCop + full test suite (what CI uses)
bundle exec rubocop      # Lint only
bundle exec rake test    # Tests only
```

### Before Committing

1. Run `./script/test` to ensure linting passes and all tests pass
2. Add tests for new functionality
3. Update README.md if changing public API
4. Update CHANGELOG.md for user-facing changes

## Common Patterns

### Defining a Model

```ruby
class Post < FMRepo::Record
  repository "/path/to/site"
  scope glob: "_posts/**/*.md", exclude: ["_posts/drafts/**"]
  
  naming do |front_matter:, **|
    slug = FMRepo.slugify(front_matter["title"])
    "_posts/#{slug}.md"
  end
  
  def title = self["title"]
  def published? = self["published"]
end
```

### Custom Relations

```ruby
class PostRelation < FMRepo::Relation
  def published
    where("published" => true)
  end
  
  def recent(days = 7)
    where("date" => FMRepo.gte(Date.today - days))
  end
end

class Post < FMRepo::Record
  relation_class PostRelation
end
```

### Creating Records

```ruby
# Automatic path from naming rule
post = Post.create!(
  { "title" => "Hello World", "published" => true },
  body: "Content here"
)

# Explicit path override
post = Post.create!(
  { "title" => "Custom" },
  body: "Content",
  path: "_posts/custom-path.md"
)
```

## Error Handling

All errors inherit from `FMRepo::Error`:

- `NotBoundError` - Model not configured with repository
- `NotFound` - Record file doesn't exist
- `UnsafePathError` - Path escapes repository root
- `ParseError` - YAML front matter parsing failed

## Reserved Field Names

Front matter fields starting with `_` are reserved:

- `_id` - Repo-relative path (string)
- `_path` - Absolute filesystem path
- `_rel_path` - Repo-relative path
- `_mtime` - File modification time
- `_model` - Model class name

## Dependencies

- Ruby 3.4.7+ (specified in `.ruby-version`)
- Bundler 4.0.2 (specified in `.bundler-version`)
- Standard library only (no external gem dependencies for runtime)
- Minitest for testing

## Important Notes for Code Generation

1. **Never bypass Repository**: Always use `FMRepo::Repository` methods for file operations
2. **Immutable Relations**: Query methods must return new relation instances, not modify existing ones
3. **Path Safety**: All paths must be validated to be within repository root
4. **Atomic Writes**: Use repository's atomic write mechanism to prevent corruption
5. **No Schema**: Front matter is schemaless YAML - no migrations or validations (v1)
6. **File-per-Record**: Each record is one file, no transactions across records
7. **Collision Handling**: Repository automatically adds suffixes (-2, -3) for naming collisions

## When Suggesting Changes

- Prefer existing patterns over introducing new paradigms
- Keep changes minimal and focused
- Add tests alongside code changes
- Consider path safety and atomic write requirements
- Match existing code style (2-space indent, frozen string literals)
- Use keyword arguments for new methods
- Document public API changes in README.md
