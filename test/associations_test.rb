# frozen_string_literal: true

require 'test_helper'

class AssociationsTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @repo = FMRepo::Repository.new(root: @tmpdir)

    # Create directories
    FileUtils.mkdir_p(File.join(@tmpdir, '_authors'))
    FileUtils.mkdir_p(File.join(@tmpdir, '_posts'))
    FileUtils.mkdir_p(File.join(@tmpdir, '_comments'))
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  # Define test models
  class Author < FMRepo::Record
    scope glob: '_authors/**/*.md'
    naming { |front_matter:, **| "_authors/#{front_matter['slug'] || 'author'}.md" }

    has_many :posts
  end

  class Post < FMRepo::Record
    scope glob: '_posts/**/*.md'
    naming { |front_matter:, **| "_posts/#{front_matter['slug'] || 'post'}.md" }

    belongs_to :author
    has_many :comments
  end

  class Comment < FMRepo::Record
    scope glob: '_comments/**/*.md'
    naming { |front_matter:, **| "_comments/#{front_matter['slug'] || 'comment'}.md" }

    belongs_to :post
  end

  # Namespaced models for testing association resolution
  module TestNamespace
    class Article < FMRepo::Record
      scope glob: '_articles/**/*.md'
      naming { |front_matter:, **| "_articles/#{front_matter['slug'] || 'article'}.md" }

      belongs_to :writer
    end

    class Writer < FMRepo::Record
      scope glob: '_writers/**/*.md'
      naming { |front_matter:, **| "_writers/#{front_matter['slug'] || 'writer'}.md" }

      has_many :articles
    end
  end

  def test_belongs_to_creates_accessor_method
    Post.repository(@repo)
    post = Post.new({ 'title' => 'Test Post' })

    assert_respond_to post, :author
  end

  def test_belongs_to_creates_setter_method
    Post.repository(@repo)
    post = Post.new({ 'title' => 'Test Post' })

    assert_respond_to post, :author=
  end

  def test_belongs_to_creates_foreign_key_getter_method
    Post.repository(@repo)
    post = Post.new({ 'title' => 'Test Post' })

    assert_respond_to post, :author_id
  end

  def test_belongs_to_creates_foreign_key_setter_method
    Post.repository(@repo)
    post = Post.new({ 'title' => 'Test Post' })

    assert_respond_to post, :author_id=
  end

  def test_belongs_to_foreign_key_getter_returns_value
    Post.repository(@repo)
    post = Post.new({ 'title' => 'Test Post', 'author_id' => '_authors/john.md' })

    assert_equal '_authors/john.md', post.author_id
  end

  def test_belongs_to_foreign_key_setter_updates_value
    Post.repository(@repo)
    post = Post.new({ 'title' => 'Test Post' })

    post.author_id = '_authors/jane.md'
    assert_equal '_authors/jane.md', post.author_id
    assert_equal '_authors/jane.md', post['author_id']
  end

  def test_belongs_to_foreign_key_setter_clears_cached_association
    Author.repository(@repo)
    Post.repository(@repo)

    author1 = Author.create!({ 'slug' => 'author1', 'name' => 'Author 1' }, body: 'Bio 1')
    author2 = Author.create!({ 'slug' => 'author2', 'name' => 'Author 2' }, body: 'Bio 2')
    post = Post.create!({ 'slug' => 'test-post', 'title' => 'Test Post', 'author_id' => author1.id }, body: 'Content')

    loaded_post = Post.find(post.id)
    # Load and cache the first author
    first_author = loaded_post.author
    assert_equal 'Author 1', first_author['name']

    # Change foreign key directly - should clear the cache
    loaded_post.author_id = author2.id

    # Should load the new author, not return the cached one
    second_author = loaded_post.author
    assert_equal 'Author 2', second_author['name']

    # Verify they are different objects
    refute_same first_author, second_author
  end

  def test_belongs_to_returns_nil_when_foreign_key_not_set
    Post.repository(@repo)
    post = Post.new({ 'title' => 'Test Post' })

    assert_nil post.author
  end

  def test_belongs_to_loads_associated_record
    Author.repository(@repo)
    Post.repository(@repo)

    # Create an author
    author = Author.create!({ 'slug' => 'john-doe', 'name' => 'John Doe' }, body: 'Bio')

    # Create a post with author_id
    post = Post.create!({ 'slug' => 'my-post', 'title' => 'My Post', 'author_id' => author.id }, body: 'Content')

    # Load the post and access the author
    loaded_post = Post.find(post.id)
    loaded_author = loaded_post.author

    assert_equal 'John Doe', loaded_author['name']
    assert_equal author.id, loaded_author.id
  end

  def test_belongs_to_returns_nil_when_associated_record_not_found
    Author.repository(@repo)
    Post.repository(@repo)

    # Create a post with invalid author_id
    post = Post.create!({ 'slug' => 'orphan-post', 'title' => 'Orphan Post', 'author_id' => '_authors/nonexistent.md' }, body: 'Content')

    loaded_post = Post.find(post.id)
    assert_nil loaded_post.author
  end

  def test_belongs_to_caches_loaded_association
    Author.repository(@repo)
    Post.repository(@repo)

    author = Author.create!({ 'slug' => 'jane-doe', 'name' => 'Jane Doe' }, body: 'Bio')
    post = Post.create!({ 'slug' => 'cached-post', 'title' => 'Cached Post', 'author_id' => author.id }, body: 'Content')

    loaded_post = Post.find(post.id)

    # First call loads
    author1 = loaded_post.author
    # Second call should return cached value
    author2 = loaded_post.author

    assert_same author1, author2
  end

  def test_belongs_to_setter_sets_foreign_key
    Author.repository(@repo)
    Post.repository(@repo)

    author = Author.create!({ 'slug' => 'author-setter', 'name' => 'Author Setter' }, body: 'Bio')
    post = Post.new({ 'slug' => 'post-with-setter', 'title' => 'Post With Setter' })

    post.author = author

    assert_equal author.id, post['author_id']
    assert_equal author.id, post.author.id
  end

  def test_belongs_to_setter_clears_foreign_key_when_nil
    Author.repository(@repo)
    Post.repository(@repo)

    author = Author.create!({ 'slug' => 'author-clear', 'name' => 'Author Clear' }, body: 'Bio')
    post = Post.new({ 'slug' => 'post-clear', 'title' => 'Post Clear' })

    post.author = author
    assert_equal author.id, post['author_id']

    post.author = nil
    assert_nil post['author_id']
    assert_nil post.author
  end

  def test_has_many_creates_accessor_method
    Author.repository(@repo)
    author = Author.new({ 'name' => 'Test Author' })

    assert_respond_to author, :posts
  end

  def test_has_many_returns_empty_relation_when_no_associations
    Author.repository(@repo)
    Post.repository(@repo)

    author = Author.create!({ 'slug' => 'lonely-author', 'name' => 'Lonely Author' }, body: 'Bio')

    posts = author.posts.to_a
    assert_equal 0, posts.length
  end

  def test_has_many_returns_associated_records
    Author.repository(@repo)
    Post.repository(@repo)

    author = Author.create!({ 'slug' => 'prolific-author', 'name' => 'Prolific Author' }, body: 'Bio')

    # Create posts for this author
    Post.create!({ 'slug' => 'post-1', 'title' => 'Post 1', 'author_id' => author.id }, body: 'Content 1')
    Post.create!({ 'slug' => 'post-2', 'title' => 'Post 2', 'author_id' => author.id }, body: 'Content 2')

    # Create a post for a different author (should not be included)
    Post.create!({ 'slug' => 'other-post', 'title' => 'Other Post', 'author_id' => '_authors/other.md' }, body: 'Content')

    posts = author.posts.to_a
    assert_equal 2, posts.length

    titles = posts.map { |p| p['title'] }.sort
    assert_equal ['Post 1', 'Post 2'], titles
  end

  def test_has_many_returns_relation_that_can_be_chained
    Author.repository(@repo)
    Post.repository(@repo)

    author = Author.create!({ 'slug' => 'chain-author', 'name' => 'Chain Author' }, body: 'Bio')

    Post.create!({ 'slug' => 'post-a', 'title' => 'A Post', 'author_id' => author.id }, body: 'Content A')
    Post.create!({ 'slug' => 'post-b', 'title' => 'B Post', 'author_id' => author.id }, body: 'Content B')
    Post.create!({ 'slug' => 'post-c', 'title' => 'C Post', 'author_id' => author.id }, body: 'Content C')

    # Test chaining
    posts = author.posts.order('title', :asc).limit(2).to_a
    assert_equal 2, posts.length
    assert_equal 'A Post', posts.first['title']
  end

  def test_has_many_caches_relation
    Author.repository(@repo)
    Post.repository(@repo)

    author = Author.create!({ 'slug' => 'cache-author', 'name' => 'Cache Author' }, body: 'Bio')

    # First call
    posts1 = author.posts
    # Second call should return cached relation
    posts2 = author.posts

    assert_same posts1, posts2
  end

  def test_nested_associations
    Author.repository(@repo)
    Post.repository(@repo)
    Comment.repository(@repo)

    # Create author -> post -> comment chain
    author = Author.create!({ 'slug' => 'nested-author', 'name' => 'Nested Author' }, body: 'Bio')
    post = Post.create!({ 'slug' => 'nested-post', 'title' => 'Nested Post', 'author_id' => author.id }, body: 'Content')
    comment = Comment.create!({ 'slug' => 'nested-comment', 'text' => 'Great post!', 'post_id' => post.id }, body: 'Comment body')

    # Navigate from comment to author through post
    loaded_comment = Comment.find(comment.id)
    assert_equal post.id, loaded_comment.post.id
    assert_equal author.id, loaded_comment.post.author.id
    assert_equal 'Nested Author', loaded_comment.post.author['name']
  end

  def test_has_many_returns_empty_relation_when_record_not_persisted
    Author.repository(@repo)
    Post.repository(@repo)

    # New record without ID
    author = Author.new({ 'name' => 'Unsaved Author' })

    posts = author.posts
    # Should return a relation (chainable), not an array
    assert_instance_of FMRepo::Relation, posts
    assert_equal 0, posts.to_a.length
    # Verify it's chainable
    assert_equal 0, posts.order('title', :asc).to_a.length
  end

  def test_belongs_to_with_namespaced_models
    # This test ensures association resolution works within namespaces
    FileUtils.mkdir_p(File.join(@tmpdir, '_writers'))
    FileUtils.mkdir_p(File.join(@tmpdir, '_articles'))

    TestNamespace::Writer.repository(@repo)
    TestNamespace::Article.repository(@repo)

    writer = TestNamespace::Writer.create!({ 'slug' => 'writer-1', 'name' => 'Test Writer' }, body: 'Bio')
    article = TestNamespace::Article.create!({ 'slug' => 'article-1', 'title' => 'Test Article', 'writer_id' => writer.id },
                                             body: 'Content')

    loaded_article = TestNamespace::Article.find(article.id)
    assert_equal 'Test Writer', loaded_article.writer['name']

    articles = writer.articles.to_a
    assert_equal 1, articles.length
    assert_equal 'Test Article', articles.first['title']
  end
end
