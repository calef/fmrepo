# frozen_string_literal: true

require 'test_helper'

class IntegrationTest < Minitest::Test
  class Place < FMRepo::Record
    scope glob: '_places/**/*.{md,markdown}'

    naming do |front_matter:, **|
      slug = FMRepo.slugify(front_matter['slug'] || front_matter['title'] || 'untitled')
      "_places/#{slug}.md"
    end

    def title = self['title']
    def county = self['county']
  end

  class PlaceRelation < FMRepo::Relation
    def in_county(name)
      where('county' => name)
    end

    def tagged(tag)
      where('tags' => FMRepo.includes(tag))
    end
  end

  class PlaceWithCustomRelation < FMRepo::Record
    scope glob: '_places/**/*.{md,markdown}'

    naming do |front_matter:, **|
      slug = FMRepo.slugify(front_matter['title'] || 'untitled')
      "_places/#{slug}.md"
    end

    relation_class PlaceRelation
  end

  class UnboundModel < FMRepo::Record
    scope glob: '*.md'
  end

  def setup
    @tmpdir = Dir.mktmpdir
    @repo = FMRepo::Repository.new(root: @tmpdir)

    # Use repository configuration
    Place.repository(@repo)
    PlaceWithCustomRelation.repository(@repo)

    # Create test files
    FileUtils.mkdir_p(File.join(@tmpdir, '_places'))

    create_place('seattle.md', {
                   'title' => 'Seattle',
                   'county' => 'King',
                   'tags' => %w[wa city]
                 }, 'Seattle description')

    create_place('bellevue.md', {
                   'title' => 'Bellevue',
                   'county' => 'King',
                   'tags' => %w[wa city]
                 }, 'Bellevue description')

    create_place('spokane.md', {
                   'title' => 'Spokane',
                   'county' => 'Spokane',
                   'tags' => %w[wa city]
                 }, 'Spokane description')
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_all_loads_all_records
    places = Place.all.to_a
    assert_equal 3, places.length
    assert(places.all? { |p| p.is_a?(Place) })
  end

  def test_where_filters_by_field
    places = Place.where('county' => 'King').to_a
    assert_equal 2, places.length
    assert(places.all? { |p| p['county'] == 'King' })
  end

  def test_where_with_predicate
    places = Place.where('tags' => FMRepo.includes('city')).to_a
    assert_equal 3, places.length
  end

  def test_order_sorts_by_field
    places = Place.order('title', :asc).to_a
    titles = places.map { |p| p['title'] }
    assert_equal %w[Bellevue Seattle Spokane], titles
  end

  def test_order_sorts_descending
    places = Place.order('title', :desc).to_a
    titles = places.map { |p| p['title'] }
    assert_equal %w[Spokane Seattle Bellevue], titles
  end

  def test_limit_restricts_results
    places = Place.limit(2).to_a
    assert_equal 2, places.length
  end

  def test_chaining_where_and_order_and_limit
    places = Place.where('county' => 'King').order('title', :desc).limit(1).to_a
    assert_equal 1, places.length
    assert_equal 'Seattle', places.first['title']
  end

  def test_find_by_id
    place = Place.find('_places/seattle.md')
    assert_equal 'Seattle', place['title']
  end

  def test_find_raises_on_not_found
    assert_raises(FMRepo::NotFound) do
      Place.find('_places/nonexistent.md')
    end
  end

  def test_find_by_returns_first_match
    place = Place.find_by('county' => 'King')
    assert place
    assert_equal 'King', place['county']
  end

  def test_find_by_returns_nil_when_no_match
    place = Place.find_by('county' => 'Nonexistent')
    assert_nil place
  end

  def test_create_with_naming_rule
    place = Place.create!({ 'title' => 'Tacoma', 'county' => 'Pierce' }, body: 'Tacoma info')

    assert place.persisted?
    refute place.new_record?
    assert_equal '_places/tacoma.md', place.id

    # Verify file exists
    assert File.exist?(File.join(@tmpdir, '_places', 'tacoma.md'))

    # Verify can be loaded
    loaded = Place.find('_places/tacoma.md')
    assert_equal 'Tacoma', loaded['title']
    assert_equal 'Pierce', loaded['county']
    assert_equal "Tacoma info\n", loaded.body
  end

  def test_create_handles_collision
    # First create
    Place.create!({ 'title' => 'Olympia' }, body: 'Capital')

    # Second create with same title should get -2 suffix
    place2 = Place.create!({ 'title' => 'Olympia' }, body: 'Duplicate')

    assert_equal '_places/olympia-2.md', place2.id
    assert File.exist?(File.join(@tmpdir, '_places', 'olympia-2.md'))
  end

  def test_save_updates_existing_record
    place = Place.find('_places/seattle.md')
    place['population'] = 750_000
    place.save!

    # Reload and verify
    reloaded = Place.find('_places/seattle.md')
    assert_equal 750_000, reloaded['population']
  end

  def test_destroy_removes_file
    place = Place.find('_places/seattle.md')
    place.destroy

    refute File.exist?(File.join(@tmpdir, '_places', 'seattle.md'))
  end

  def test_reload_refreshes_from_disk
    place = Place.find('_places/seattle.md')
    place['title']

    # Modify on disk
    path = File.join(@tmpdir, '_places', 'seattle.md')
    content = File.read(path)
    content.sub!('title: Seattle', 'title: Seattle Updated')
    File.write(path, content)

    place.reload
    assert_equal 'Seattle Updated', place['title']
  end

  def test_custom_relation_method
    places = PlaceWithCustomRelation.all.in_county('King').to_a
    assert_equal 2, places.length
    assert(places.all? { |p| p['county'] == 'King' })
  end

  def test_custom_relation_tagged_method
    places = PlaceWithCustomRelation.all.tagged('city').to_a
    assert_equal 3, places.length
  end

  def test_predicates_includes
    pred = FMRepo.includes('ruby')
    assert pred.call(%w[ruby rails])
    assert pred.call('ruby on rails')
    refute pred.call(['python'])
    refute pred.call('python')
  end

  def test_predicates_in_set
    pred = FMRepo.in_set(%w[a b c])
    assert pred.call('a')
    refute pred.call('d')
  end

  def test_predicates_present
    pred = FMRepo.present
    assert pred.call('text')
    assert pred.call([1])
    assert pred.call({ key: 'value' })
    refute pred.call(nil)
    refute pred.call('')
    refute pred.call('  ')
    refute pred.call([])
    refute pred.call({})
  end

  def test_predicates_matches
    pred = FMRepo.matches(/^test/)
    assert pred.call('testing')
    refute pred.call('not matching')
    refute pred.call(123)
  end

  def test_predicates_comparison
    assert FMRepo.gt(5).call(10)
    refute FMRepo.gt(5).call(3)

    assert FMRepo.gte(5).call(5)
    assert FMRepo.gte(5).call(10)

    assert FMRepo.lt(10).call(5)
    refute FMRepo.lt(10).call(15)

    assert FMRepo.lte(10).call(10)
    assert FMRepo.lte(10).call(5)

    assert FMRepo.between(5, 10).call(7)
    refute FMRepo.between(5, 10).call(3)
  end

  def test_slugify
    assert_equal 'hello-world', FMRepo.slugify('Hello World')
    assert_equal 'hello-world', FMRepo.slugify('hello world')
    assert_equal 'hello-world', FMRepo.slugify('Hello, World!')
    assert_equal 'test-123', FMRepo.slugify('Test 123')
    assert_equal 'untitled', FMRepo.slugify('')
    assert_equal 'untitled', FMRepo.slugify('   ')
    assert_equal 'tests', FMRepo.slugify("test's")
  end

  def test_not_bound_error
    assert_raises(FMRepo::NotBoundError) do
      UnboundModel.all.to_a
    end
  end

  def test_reserved_fields
    place = Place.find('_places/seattle.md')

    # Test _id
    assert_equal '_places/seattle.md', Place.where('_id' => '_places/seattle.md').first.id

    # Test _model
    assert_equal 'IntegrationTest::Place', Place.where('_model' => 'IntegrationTest::Place').first.class.name

    # Test _path
    results = Place.where('_path' => place.path.to_s).to_a
    assert_equal 1, results.length
  end

  private

  def create_place(filename, front_matter, body)
    path = File.join(@tmpdir, '_places', filename)
    content = "---\n"
    content += YAML.dump(front_matter).sub(/\A---\s*\n/, '')
    content += "---\n\n"
    content += body
    content += "\n"
    File.write(path, content)
  end
end
