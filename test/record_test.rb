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

  def test_id_returns_relative_path
    path = File.join(@tmpdir, 'test.md')
    rec = FMRepo::Record.new({ 'title' => 'Test' }, path: path, repo: @repo)

    assert_equal 'test.md', rec.id
  end

  def test_id_returns_nil_without_path_or_repo
    rec = FMRepo::Record.new({ 'title' => 'Test' })
    assert_nil rec.id
  end

  def test_rel_path_returns_pathname
    path = File.join(@tmpdir, 'test.md')
    rec = FMRepo::Record.new({ 'title' => 'Test' }, path: path, repo: @repo)

    assert_instance_of Pathname, rec.rel_path
    assert_equal 'test.md', rec.rel_path.to_s
  end
end
