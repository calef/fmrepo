# FMRepo

## File-Backed Front-Matter Markdown ORM for Static-Site Repositories

FMRepo provides an Active Record-like interface for managing Markdown files with YAML front matter in static site repositories. Perfect for Jekyll-style collections and custom static site generators.

## Features

- **Active Record-style API**: Familiar `where`, `order`, `limit`, `find`, `create!` methods
- **Chainable queries**: Build complex queries with immutable relation objects
- **Type-per-directory**: Define one model class per collection/directory
- **Custom naming rules**: Control file naming and collision resolution
- **Safe filesystem operations**: Atomic writes, path validation, and collision handling
- **Flexible predicates**: Query with equality, inclusion, comparisons, regex, and custom predicates
- **Custom relations**: Extend with domain-specific query methods

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fmrepo'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install fmrepo
```

## Quick Start

```ruby
require 'fmrepo'

# Define a model for your collection with repository path
class Place < FMRepo::Record
  repository "/path/to/site"  # Configure repository at class definition
  scope glob: "_places/**/*.{md,markdown}"

  naming do |front_matter:, **|
    slug = FMRepo.slugify(front_matter["title"])
    "_places/#{slug}.md"
  end

  def title = self["title"]
  def county = self["county"]
end

# Query records
Place.where("county" => "King").order("title").limit(10).each do |place|
  puts place.title
end

# Create new records
place = Place.create!(
  { "title" => "Seattle", "county" => "King" },
  body: "Seattle is the largest city in Washington state."
)

# Update and save
place["population"] = 750_000
place.save!

# Delete records
place.destroy
```

## Differences from Active Record

While FMRepo provides an Active Record-like interface, there are key differences:

| Feature | Active Record | FMRepo |
|---------|--------------|--------|
| **Data Source** | Database tables | Markdown files with front matter |
| **Model Configuration** | Database connection configured globally | Repository path configured per model class |
| **Record Identity** | Primary key (usually `id` column) | File path relative to repository root |
| **Schema** | Defined in migrations | Flexible YAML front matter (no schema) |
| **Relationships** | Associations (has_many, belongs_to) | Not supported (v1) |
| **Transactions** | Database transactions | Not supported (file-per-record) |
| **Callbacks** | Before/after hooks | Not supported (v1) |
| **Validations** | Built-in validation framework | Not supported (v1) |
| **Query Interface** | SQL-based with rich DSL | File-based with predicates |
| **Persistence** | Row in database | Markdown file with YAML front matter |

### Key Similarities

- Chainable query interface (`where`, `order`, `limit`)
- Instance methods for persistence (`save!`, `destroy`, `reload`)
- Class methods for finding records (`find`, `find_by`, `all`)
- Attribute accessors (front matter fields via `[]` and `[]=`)

### When to use FMRepo vs Active Record

- Use FMRepo for static site generators, documentation sites, or file-based content management
- Use Active Record for traditional web applications with relational data and complex queries

## Core Concepts

### Repository

The `FMRepo::Repository` class handles all filesystem operations:

```ruby
repo = FMRepo::Repository.new(root: "/path/to/site")
```

Features:

- Path safety: All operations are validated to be within the repository root
- Atomic writes: Files are written atomically to prevent corruption
- Collision resolution: Automatically handles filename conflicts

### Record

`FMRepo::Record` is the base class for your models. Each record represents a single Markdown file with front matter.

```ruby
class Post < FMRepo::Record
  repository "/path/to/site"  # Configure repository path
  scope glob: "_posts/**/*.md"

  naming do |front_matter:, **|
    date = front_matter["date"]&.strftime("%Y-%m-%d") || Time.now.strftime("%Y-%m-%d")
    slug = FMRepo.slugify(front_matter["title"])
    "_posts/#{date}-#{slug}.md"
  end
end
```

**Repository Configuration**: Specify the repository path at class definition:

```ruby
class Post < FMRepo::Record
  repository "/path/to/site"  # Path string
  # or
  repository FMRepo::Repository.new(root: "/path/to/site")  # Repository instance
end
```

**Scoping**: Define which files belong to this model:

```ruby
scope glob: "_posts/**/*.md", exclude: ["_posts/drafts/**"]
```

**Naming rules**: Control how new files are named:

```ruby
naming do |front_matter:, body:, repo:, **opts|
  # Return a repo-relative path string
  "_posts/#{FMRepo.slugify(front_matter["title"])}.md"
end
```

### Relation

`FMRepo::Relation` provides chainable query interface:

```ruby
# Basic queries
Post.where("published" => true)
    .order("date", :desc)
    .limit(10)
    .to_a

# With predicates
Post.where("tags" => FMRepo.includes("ruby"))
    .where("date" => FMRepo.gt(Date.new(2024, 1, 1)))
```

**Custom relations**: Add domain-specific query methods:

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

# Usage
Post.published.recent.to_a
```

## Query API

### Class Methods

- `all` - Returns a relation for all records
- `where(criteria)` - Filter records by criteria
- `order(field, direction)` - Sort by field (`:asc` or `:desc`)
- `limit(n)` - Limit number of results
- `offset(n)` - Skip first n results
- `find(id)` - Find by repo-relative path
- `find_by(criteria)` - Find first matching record
- `create!(attrs, body:, path:)` - Create and save a new record

### Instance Methods

- `save!` - Save changes to disk
- `destroy` - Delete the file
- `reload` - Refresh from disk
- `[key]` - Get front matter value
- `[key]=` - Set front matter value
- `body` - Get/set body content
- `id` - Get repo-relative path
- `persisted?` - Check if saved
- `new_record?` - Check if new

### Predicates

Built-in predicates for querying:

```ruby
# Inclusion
FMRepo.includes("ruby")        # Array/String includes value
FMRepo.in_set(["a", "b", "c"]) # Value is in set

# Presence
FMRepo.present                  # Not nil/empty

# Pattern matching
FMRepo.matches(/regex/)         # String matches regex

# Comparisons
FMRepo.gt(5)                    # Greater than
FMRepo.gte(5)                   # Greater than or equal
FMRepo.lt(5)                    # Less than
FMRepo.lte(5)                   # Less than or equal
FMRepo.between(1, 10)           # Between values
```

### Reserved Fields

Query special built-in fields:

- `_id` - Repo-relative path as string
- `_path` - Absolute path as string
- `_rel_path` - Repo-relative path as string
- `_mtime` - File modification time
- `_model` - Model class name

```ruby
Place.where("_mtime" => FMRepo.gt(Time.now - 3600))
     .order("_id")
     .to_a
```

## Advanced Usage

### Multiple Collections

```ruby
# Each model class specifies its own repository
class Place < FMRepo::Record
  repository "/path/to/site"
  scope glob: "_places/**/*.md"
end

class Post < FMRepo::Record
  repository "/path/to/site"
  scope glob: "_posts/**/*.md"
end

class Organization < FMRepo::Record
  repository "/path/to/site"
  scope glob: "_organizations/**/*.md"
end

# Each model operates on its own scope
places = Place.all.to_a
posts = Post.where("published" => true).to_a
```

### Custom Predicates

Create custom predicates for complex queries:

```ruby
# Define a custom predicate
def published_in_year(year)
  ->(date) { date.is_a?(Date) && date.year == year }
end

# Use it
Post.where("date" => published_in_year(2024))
```

### Front Matter Parsing

FMRepo parses YAML front matter automatically:

```markdown
---
title: Example Post
tags:
  - ruby
  - rails
published: true
---

This is the body content.
```

Becomes:

```ruby
post["title"]     # => "Example Post"
post["tags"]      # => ["ruby", "rails"]
post["published"] # => true
post.body         # => "This is the body content.\n"
```

### Collision Resolution

When creating files, collisions are automatically resolved:

```ruby
Place.create!({"title" => "Seattle"})  # => _places/seattle.md
Place.create!({"title" => "Seattle"})  # => _places/seattle-2.md
Place.create!({"title" => "Seattle"})  # => _places/seattle-3.md
```

## Error Handling

FMRepo defines specific error classes:

- `FMRepo::Error` - Base error class
- `FMRepo::NotBoundError` - Model not bound to repository
- `FMRepo::NotFound` - Record not found
- `FMRepo::UnsafePathError` - Path outside repository root
- `FMRepo::ParseError` - YAML parsing error

```ruby
begin
  Place.find("nonexistent.md")
rescue FMRepo::NotFound => e
  puts "Not found: #{e.message}"
end
```

## Testing

Run RuboCop and the test suite:

```bash
script/test
```

Or run them individually:

```bash
bundle exec rubocop
bundle exec rake test
ruby -Ilib:test test/integration_test.rb
```

### Environment-driven repositories (Active Record style)

FMRepo can pick repositories by environment instead of configuring each model manually. The environment defaults to `FMREPO_ENV`, then `JEKYLL_ENV`, then `RACK_ENV`, then `RAILS_ENV`, falling back to `development`.

```yaml
# .fmrepo.yml
default:
  development: /sites/dev
  test: <tmp>         # create a temp repo automatically
  production: /sites/live
places:
  production: /sites/live/_places
```

```ruby
# config/initializers/fmrepo.rb
FMRepo.configure do |c|
  c.load_yaml('.fmrepo.yml')
end
```

```ruby
class Place < FMRepo::Record
  repository_role :places   # optional; defaults to :default
  scope glob: '_places/**/*.md'
  naming { |front_matter:, **| "_places/#{FMRepo.slugify(front_matter['title'] || 'untitled')}.md" }
end
```

Testing with temporary repositories:

```ruby
require 'fmrepo/test_helpers'

class Minitest::Test
  def setup
    @repo_override = FMRepo::TestHelpers.with_temp_repo # uses FMRepo.environment
  end

  def teardown
    @repo_override&.cleanup
  end
end
```

All models using the configured role now write to a disposable repo in tests without subclassing.

Best practices:
- Keep repository paths in `.fmrepo.yml`; avoid calling `repository` in production code unless you truly need an override.
- Use roles (`repository_role :places`) for collections that map to different roots; default role works for single-repo apps.
- For tests, set the `test` entry to `<tmp>` or wrap examples with `FMRepo::TestHelpers.with_temp_repo` to isolate filesystem writes.
- Set `FMREPO_ENV` explicitly for non-Rails apps or scripts; Rails apps will pick up `RAILS_ENV`.
- When you must override a single model (e.g., a one-off migration), `Model.repository('/path')` still works and bypasses the registry for that class only.

## Development

After checking out the repo, use the provided scripts for development:

### Bootstrap

Set up your development environment:

```bash
script/bootstrap
```

This will ensure you have the correct Ruby version and all dependencies installed.

### Running Tests

Run linting and tests together:

```bash
script/test
```

Or run just the test suite:

```bash
bundle exec rake test
```

### CI Build

Run the full CI build locally:

```bash
script/cibuild
```

### Update Dependencies

Update gems to their latest versions:

```bash
script/update
```

### Building the Gem

To build the gem:

```bash
gem build fmrepo.gemspec
```

### Development Scripts

The `script/` directory contains several helper scripts:

- `script/bootstrap` - Set up development environment
- `script/test` - Run test suite
- `script/cibuild` - Run CI build
- `script/update` - Update dependencies
- `script/ensure-*` - Ensure specific tools are installed (bundler, ruby, homebrew, etc.)

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/calef/fmrepo](https://github.com/calef/fmrepo).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
