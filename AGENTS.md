# Repository Guidelines

## Project Structure & Module Organization
- `lib/` contains the runtime: `fmrepo.rb` boots errors, repository (path safety, atomic writes), record (model DSL + naming), relation, predicates, model_config, and version.
- `test/` holds the Minitest suites (`*_test.rb`) and `test_helper.rb` load path setup; add coverage beside the code you touch.
- `examples/basic_usage.rb` is a minimal usage script—keep samples small and focused.
- `script/` automation (`bootstrap`, `test`, `cibuild`, `ensure-*`) handles setup and repeatable runs; prefer these over ad-hoc commands.

## Setup & Environment
- Ruby 3.4.7 and Bundler 4.0.1 are required (`.ruby-version`, `.bundler-version`, `.ruby-gemset`). Run `./script/bootstrap` to install via mise + bundler and to clear any `bundle config without` settings.
- Use `bundle exec` for Ruby invocations so they respect the locked gems in `Gemfile.lock`.

## Build, Test, and Development Commands
- `./script/bootstrap` — install the toolchain and gems.
- `./script/test` — run RuboCop then the full Minitest suite (also what CI invokes via `script/cibuild`).
- `bundle exec rubocop` — lint the codebase directly.
- `bundle exec rake test` — run only the Minitest suite; `bundle exec rake` aliases this.
- `bundle exec ruby examples/basic_usage.rb` — execute the sample script against a local repository copy to sanity-check API changes.

## Coding Style & Naming Conventions
- Ruby style with 2-space indentation and `# frozen_string_literal: true` headers; prefer small, focused classes and explicit keyword args (see `FMRepo::Record` APIs).
- Files use `snake_case.rb`; classes/modules use `CamelCase`; predicates and scopes should read fluently (e.g., `where("tags" => FMRepo.includes("ruby"))`).
- Keep filesystem operations wrapped in `FMRepo::Repository`; avoid direct `File` writes in new features.

## Testing Guidelines
- Add `*_test.rb` under `test/`, inheriting from `Minitest::Test`; mirror runtime structure (`test/repository_test.rb`, etc.).
- Exercise both success and failure cases: path validation, collision handling, predicate behavior, and atomic writes.
- Use temporary directories (`Dir.mktmpdir`) and inline fixtures; avoid committing sample content to the repo.

## Commit & Pull Request Guidelines
- Commit messages: short, imperative summaries (see history: "update bundler", "Add ... workflow"); include context in the body if needed.
- PRs should describe intent, list key changes, note tests run (`./script/test`), and link issues. Include screenshots only when altering docs or example output.
- Update README or CHANGELOG when modifying public APIs or setup steps; coordinate version bumps with the gemspec.
