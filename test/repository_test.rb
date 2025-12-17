# frozen_string_literal: true

require 'test_helper'

class RepositoryTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @repo = FMRepo::Repository.new(root: @tmpdir)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_root_is_expanded_pathname
    assert_instance_of Pathname, @repo.root
    assert @repo.root.absolute?
  end

  def test_glob_returns_pathnames
    FileUtils.mkdir_p(File.join(@tmpdir, 'subdir'))
    File.write(File.join(@tmpdir, 'file1.md'), 'content')
    File.write(File.join(@tmpdir, 'subdir', 'file2.md'), 'content')

    results = @repo.glob('**/*.md')
    assert_equal 2, results.length
    assert(results.all? { |p| p.is_a?(Pathname) })
  end

  def test_read_returns_file_content
    path = File.join(@tmpdir, 'test.md')
    content = 'Hello World'
    File.write(path, content)

    assert_equal content, @repo.read(path)
  end

  def test_read_raises_on_path_outside_root
    outside_path = '/tmp/outside.md'
    assert_raises(FMRepo::UnsafePathError) do
      @repo.read(outside_path)
    end
  end

  def test_write_atomic_creates_file
    rel_path = 'new/file.md'
    abs_path = @repo.abs(rel_path)
    content = 'New content'

    @repo.write_atomic(abs_path, content)

    assert File.exist?(abs_path)
    assert_equal content, File.read(abs_path)
  end

  def test_write_atomic_creates_parent_directories
    rel_path = 'deep/nested/path/file.md'
    abs_path = @repo.abs(rel_path)

    @repo.write_atomic(abs_path, 'content')

    assert File.exist?(abs_path)
  end

  def test_write_atomic_raises_on_path_outside_root
    assert_raises(FMRepo::UnsafePathError) do
      @repo.write_atomic('/tmp/outside.md', 'content')
    end
  end

  def test_delete_removes_file
    path = File.join(@tmpdir, 'test.md')
    File.write(path, 'content')

    @repo.delete(path)

    refute File.exist?(path)
  end

  def test_delete_raises_on_path_outside_root
    assert_raises(FMRepo::UnsafePathError) do
      @repo.delete('/tmp/outside.md')
    end
  end

  def test_resolve_collision_returns_original_if_no_collision
    rel = @repo.resolve_collision('test.md')
    assert_equal 'test.md', rel.to_s
  end

  def test_resolve_collision_adds_number_on_collision
    File.write(File.join(@tmpdir, 'test.md'), 'content')

    rel = @repo.resolve_collision('test.md')
    assert_equal 'test-2.md', rel.to_s
  end

  def test_resolve_collision_increments_until_free
    File.write(File.join(@tmpdir, 'test.md'), 'content')
    File.write(File.join(@tmpdir, 'test-2.md'), 'content')
    File.write(File.join(@tmpdir, 'test-3.md'), 'content')

    rel = @repo.resolve_collision('test.md')
    assert_equal 'test-4.md', rel.to_s
  end

  def test_abs_converts_relative_to_absolute
    rel = 'subdir/file.md'
    abs = @repo.abs(rel)

    assert_instance_of Pathname, abs
    assert abs.absolute?
    assert abs.to_s.start_with?(@tmpdir)
  end

  def test_rel_converts_absolute_to_relative
    abs = File.join(@tmpdir, 'subdir', 'file.md')
    rel = @repo.rel(abs)

    assert_instance_of Pathname, rel
    assert_equal 'subdir/file.md', rel.to_s
  end

  def test_assert_within_root_allows_paths_in_root
    path = File.join(@tmpdir, 'file.md')
    assert_nil @repo.assert_within_root!(path)
  end

  def test_assert_within_root_raises_on_path_outside
    assert_raises(FMRepo::UnsafePathError) do
      @repo.assert_within_root!('/tmp/outside.md')
    end
  end
end
