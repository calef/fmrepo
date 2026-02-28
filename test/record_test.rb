# frozen_string_literal: true

require 'test_helper'

class RecordTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @repo = FMRepo::Repository.new(root: @tmpdir)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_record_initialization
    rec = FMRepo::Record.new({ 'title' => 'Test' }, body: 'Content')
    assert_equal 'Test', rec['title']
    assert_equal 'Content', rec.body
    assert rec.new_record?
    refute rec.persisted?
  end

  def test_front_matter_access
    rec = FMRepo::Record.new({ 'title' => 'Test', 'tags' => ['ruby'] })
    assert_equal 'Test', rec['title']
    assert_equal ['ruby'], rec['tags']
  end

  def test_front_matter_assignment
    rec = FMRepo::Record.new
    rec['title'] = 'New Title'
    assert_equal 'New Title', rec['title']
  end

  def test_parse_front_matter_with_valid_yaml
    content = <<~MD
      ---
      title: Test Post
      tags:
        - ruby
        - rails
      ---

      This is the body.
    MD

    fm, body = FMRepo::Record.parse_front_matter(content)
    assert_equal 'Test Post', fm['title']
    assert_equal %w[ruby rails], fm['tags']
    assert_equal "This is the body.\n", body
  end

  def test_parse_front_matter_with_empty_front_matter
    content = <<~MD
      ---
      ---

      Body content.
    MD

    fm, body = FMRepo::Record.parse_front_matter(content)
    assert_equal({}, fm)
    assert_equal "Body content.\n", body
  end

  def test_parse_front_matter_without_front_matter
    content = 'Just plain content'
    fm, body = FMRepo::Record.parse_front_matter(content)
    assert_equal({}, fm)
    assert_equal 'Just plain content', body
  end

  def test_parse_front_matter_with_ellipsis_delimiter
    content = <<~MD
      ---
      title: Test
      ...

      Body
    MD

    fm, body = FMRepo::Record.parse_front_matter(content)
    assert_equal 'Test', fm['title']
    assert_equal "Body\n", body
  end

  def test_parse_front_matter_raises_on_invalid_yaml
    content = <<~MD
      ---
      title: Test
      invalid: [unclosed
      ---

      Body
    MD

    assert_raises(FMRepo::ParseError) do
      FMRepo::Record.parse_front_matter(content)
    end
  end

  def test_parse_front_matter_raises_on_unclosed_delimiter
    content = <<~MD
      ---
      title: Test
      tags: []
    MD

    assert_raises(FMRepo::ParseError) do
      FMRepo::Record.parse_front_matter(content)
    end
  end

  def test_serialize_with_front_matter_and_body
    rec = FMRepo::Record.new({ 'title' => 'Test' }, body: 'Body content')
    serialized = rec.serialize

    assert serialized.start_with?("---\n")
    assert serialized.include?('title: Test')
    assert serialized.include?('Body content')
    assert serialized.end_with?("\n")
  end

  def test_serialize_with_empty_front_matter
    rec = FMRepo::Record.new({}, body: 'Just body')
    serialized = rec.serialize

    assert serialized.start_with?("---\n")
    assert serialized.include?('Just body')
  end

  def test_serialize_sorts_keys_alphabetically
    rec = FMRepo::Record.new({ 'zebra' => 'last', 'apple' => 'first', 'middle' => 'middle' }, body: 'Body')
    serialized = rec.serialize

    # Parse the serialized content back to verify key order
    fm, _body = FMRepo::Record.parse_front_matter(serialized)
    keys = fm.keys

    # Verify keys are in alphabetical order
    assert_equal %w[apple middle zebra], keys
    assert_equal 'first', fm['apple']
    assert_equal 'middle', fm['middle']
    assert_equal 'last', fm['zebra']
  end

  def test_id_returns_relative_path
    path = File.join(@tmpdir, 'test.md')
    rec = FMRepo::Record.new({ 'title' => 'Test' }, path:, repo: @repo)

    assert_equal 'test.md', rec.id
  end

  def test_id_returns_nil_without_path_or_repo
    rec = FMRepo::Record.new({ 'title' => 'Test' })
    assert_nil rec.id
  end

  def test_rel_path_returns_pathname
    path = File.join(@tmpdir, 'test.md')
    rec = FMRepo::Record.new({ 'title' => 'Test' }, path:, repo: @repo)

    assert_instance_of Pathname, rec.rel_path
    assert_equal 'test.md', rec.rel_path.to_s
  end

  def test_scope_config_returns_hash_with_scope_settings
    klass = Class.new(FMRepo::Record) do
      scope glob: '_posts/**/*.md', exclude: ['drafts/**'], extensions: %w[.md .markdown]
    end

    config = klass.scope_config
    assert_instance_of Hash, config
    assert_equal '_posts/**/*.md', config[:glob]
    assert_equal ['drafts/**'], config[:exclude]
    assert_equal %w[.md .markdown], config[:extensions]
  end

  def test_scope_config_returns_defaults_when_scope_not_called
    klass = Class.new(FMRepo::Record)

    config = klass.scope_config
    assert_instance_of Hash, config
    assert_nil config[:glob]
    assert_equal [], config[:exclude]
    assert_nil config[:extensions]
  end

  def test_attribute_creates_getter_and_setter
    klass = Class.new(FMRepo::Record) do
      attribute :title, :date
    end

    rec = klass.new
    assert_nil rec.title
    rec.title = 'Test Title'
    assert_equal 'Test Title', rec.title
    assert_equal 'Test Title', rec['title']
  end

  def test_attribute_with_default_returns_default_when_nil
    klass = Class.new(FMRepo::Record) do
      attribute :tags, default: []
    end

    rec = klass.new
    assert_equal [], rec.tags

    rec.tags = %w[ruby rails]
    assert_equal %w[ruby rails], rec.tags
  end

  def test_attribute_with_default_does_not_return_default_when_explicitly_set
    klass = Class.new(FMRepo::Record) do
      attribute :tags, default: ['default']
    end

    rec = klass.new
    rec['tags'] = []
    assert_equal [], rec.tags
  end

  def test_attribute_with_mutable_default_does_not_share_between_instances
    klass = Class.new(FMRepo::Record) do
      attribute :tags, default: []
    end

    rec1 = klass.new
    rec2 = klass.new

    rec1.tags << 'ruby'
    assert_equal ['ruby'], rec1.tags
    assert_equal [], rec2.tags # Should not be affected by rec1's modification
  end

  def test_boolean_attribute_creates_getter_setter_and_predicate
    klass = Class.new(FMRepo::Record) do
      boolean_attribute :locked
    end

    rec = klass.new
    assert_nil rec.locked
    refute rec.locked?

    rec.locked = true
    assert rec.locked?

    rec.locked = false
    refute rec.locked?
  end

  def test_boolean_attribute_with_default_false_requires_explicit_true
    klass = Class.new(FMRepo::Record) do
      boolean_attribute :summarized
    end

    rec = klass.new
    refute rec.summarized?

    rec.summarized = 'yes'
    refute rec.summarized?

    rec.summarized = true
    assert rec.summarized?
  end

  def test_boolean_attribute_with_default_true_returns_true_unless_false
    klass = Class.new(FMRepo::Record) do
      boolean_attribute :published, default: true
    end

    rec = klass.new
    assert rec.published?

    rec.published = nil
    assert rec.published?

    rec.published = 'anything'
    assert rec.published?

    rec.published = false
    refute rec.published?
  end

  def test_attributes_with_defaults_returns_attribute_names
    klass = Class.new(FMRepo::Record) do
      attribute :title
      attribute :tags, default: []
      attribute :count, default: 0
    end

    assert_equal %w[tags count], klass.attributes_with_defaults
  end

  def test_attributes_with_defaults_includes_inherited_attributes
    parent = Class.new(FMRepo::Record) do
      attribute :tags, default: []
    end

    child = Class.new(parent) do
      attribute :categories, default: []
    end

    assert_equal %w[tags], parent.attributes_with_defaults
    assert_equal %w[tags categories], child.attributes_with_defaults
  end

  def test_save_materializes_attribute_defaults
    klass = Class.new(FMRepo::Record) do
      attribute :tags, default: []
      attribute :metadata, default: {}
    end

    path = File.join(@tmpdir, 'test.md')
    rec = klass.new({ 'title' => 'Test' }, body: '', path: path, repo: @repo)
    rec.save!

    content = File.read(path)
    assert_includes content, 'tags: []'
    assert_includes content, 'metadata: {}'
  end

  def test_save_materializes_boolean_attribute_default_true
    klass = Class.new(FMRepo::Record) do
      boolean_attribute :published, default: true
    end

    path = File.join(@tmpdir, 'test.md')
    rec = klass.new({ 'title' => 'Test' }, body: '', path: path, repo: @repo)
    rec.save!

    content = File.read(path)
    assert_includes content, 'published: true'
  end

  def test_save_does_not_overwrite_explicit_false_for_boolean_attribute_default_true
    klass = Class.new(FMRepo::Record) do
      boolean_attribute :published, default: true
    end

    path = File.join(@tmpdir, 'test.md')
    rec = klass.new({ 'title' => 'Test', 'published' => false }, body: '', path: path, repo: @repo)
    rec.save!

    content = File.read(path)
    assert_includes content, 'published: false'
  end

  def test_save_does_not_materialize_boolean_attribute_default_false
    klass = Class.new(FMRepo::Record) do
      boolean_attribute :locked
    end

    path = File.join(@tmpdir, 'test.md')
    rec = klass.new({ 'title' => 'Test' }, body: '', path: path, repo: @repo)
    rec.save!

    content = File.read(path)
    refute_includes content, 'locked'
  end

  def test_save_does_not_overwrite_explicit_values_with_defaults
    klass = Class.new(FMRepo::Record) do
      attribute :tags, default: []
    end

    path = File.join(@tmpdir, 'test.md')
    rec = klass.new({ 'title' => 'Test', 'tags' => %w[ruby rails] }, body: '', path: path, repo: @repo)
    rec.save!

    content = File.read(path)
    assert_includes content, 'ruby'
    assert_includes content, 'rails'
  end

  def test_dirty_returns_true_for_new_record
    rec = FMRepo::Record.new({ 'title' => 'Test' })
    assert rec.dirty?
  end

  def test_dirty_returns_false_after_save
    path = File.join(@tmpdir, 'test.md')
    rec = FMRepo::Record.new({ 'title' => 'Test' }, body: '', path: path, repo: @repo)
    rec.save!
    refute rec.dirty?
  end

  def test_dirty_returns_true_after_modification
    path = File.join(@tmpdir, 'test.md')
    rec = FMRepo::Record.new({ 'title' => 'Test' }, body: '', path: path, repo: @repo)
    rec.save!
    refute rec.dirty?

    rec['title'] = 'Updated'
    assert rec.dirty?
  end

  def test_dirty_returns_false_after_reload
    path = File.join(@tmpdir, 'test.md')
    rec = FMRepo::Record.new({ 'title' => 'Test' }, body: '', path: path, repo: @repo)
    rec.save!
    rec['title'] = 'Modified'
    assert rec.dirty?

    rec.reload
    refute rec.dirty?
  end

  def test_load_from_path_front_matter_only_skips_body
    record = FMRepo::Record.new({ 'title' => 'Test', 'count' => 42 }, body: 'Big XML body here')
    record.instance_variable_set(:@repo, @repo)
    record.instance_variable_set(:@path, Pathname.new(File.join(@tmpdir, 'test.md')))
    record.instance_variable_set(:@new_record, false)
    @repo.write_atomic(record.path, record.serialize)

    loaded = FMRepo::Record.load_from_path(repo: @repo, abs_path: record.path, front_matter_only: true)

    assert loaded.front_matter_only?
    assert_equal 'Test', loaded['title']
    assert_equal 42, loaded['count']
    assert_nil loaded.body
  end

  def test_front_matter_only_save_preserves_body
    record = FMRepo::Record.new({ 'title' => 'Original' }, body: 'Preserved body content')
    record.instance_variable_set(:@repo, @repo)
    record.instance_variable_set(:@path, Pathname.new(File.join(@tmpdir, 'patch_test.md')))
    record.instance_variable_set(:@new_record, false)
    @repo.write_atomic(record.path, record.serialize)

    # Load front-matter-only and update a field
    fm_record = FMRepo::Record.load_from_path(repo: @repo, abs_path: record.path, front_matter_only: true)
    fm_record['title'] = 'Updated'
    fm_record['refreshed_at'] = '2026-01-01T00:00:00Z'
    fm_record.save!

    # Reload the full record and verify body was preserved
    full_record = FMRepo::Record.load_from_path(repo: @repo, abs_path: record.path)
    assert_equal 'Updated', full_record['title']
    assert_equal '2026-01-01T00:00:00Z', full_record['refreshed_at']
    assert_equal 'Preserved body content', full_record.body.strip
  end

  def test_body_assignment_clears_front_matter_only
    record = FMRepo::Record.new({ 'title' => 'Test' }, body: 'original body')
    record.instance_variable_set(:@repo, @repo)
    record.instance_variable_set(:@path, Pathname.new(File.join(@tmpdir, 'body_clear_test.md')))
    record.instance_variable_set(:@new_record, false)
    record.instance_variable_set(:@front_matter_only, true)

    assert record.front_matter_only?
    record.body = 'new body'
    refute record.front_matter_only?
  end

  def test_reload_clears_front_matter_only
    record = FMRepo::Record.new({ 'title' => 'Test' }, body: 'body content')
    record.instance_variable_set(:@repo, @repo)
    record.instance_variable_set(:@path, Pathname.new(File.join(@tmpdir, 'reload_clear_test.md')))
    record.instance_variable_set(:@new_record, false)
    @repo.write_atomic(record.path, record.serialize)

    fm_record = FMRepo::Record.load_from_path(repo: @repo, abs_path: record.path, front_matter_only: true)
    assert fm_record.front_matter_only?

    fm_record.reload
    refute fm_record.front_matter_only?
    assert_equal 'body content', fm_record.body.strip
  end
end
