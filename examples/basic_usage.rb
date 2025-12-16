#!/usr/bin/env ruby
# frozen_string_literal: true

# Example usage of FMRepo
require 'bundler/setup'
require 'fmrepo'
require 'tmpdir'
require 'fileutils'

# Create a temporary directory for our example site
site_root = Dir.mktmpdir
puts "Created example site at: #{site_root}"

begin
  # Define a model for places with custom relation
  class PlaceRelation < FMRepo::Relation
    def in_county(name)
      where('county' => name)
    end

    def tagged(tag)
      where('tags' => FMRepo.includes(tag))
    end

    def recent
      order('_mtime', :desc)
    end
  end

  class Place < FMRepo::Record
    scope glob: '_places/**/*.{md,markdown}'

    naming do |front_matter:, **|
      slug = FMRepo.slugify(front_matter['slug'] || front_matter['title'] || 'untitled')
      "_places/#{slug}.md"
    end

    relation_class PlaceRelation

    def title = self['title']
    def county = self['county']
    def tags = self['tags'] || []
  end

  # Create and bind repository
  repo = FMRepo::Repository.new(root: site_root)
  Place.bind(repo)

  puts "\n=== Creating Places ==="

  # Create some example places
  seattle = Place.create!(
    {
      'title' => 'Seattle',
      'county' => 'King',
      'tags' => %w[wa city coast],
      'population' => 750_000
    },
    body: 'Seattle is the largest city in Washington state.'
  )
  puts "Created: #{seattle.title} (#{seattle.id})"

  bellevue = Place.create!(
    {
      'title' => 'Bellevue',
      'county' => 'King',
      'tags' => %w[wa city],
      'population' => 150_000
    },
    body: 'Bellevue is located on the Eastside.'
  )
  puts "Created: #{bellevue.title} (#{bellevue.id})"

  spokane = Place.create!(
    {
      'title' => 'Spokane',
      'county' => 'Spokane',
      'tags' => %w[wa city],
      'population' => 230_000
    },
    body: 'Spokane is the largest city in Eastern Washington.'
  )
  puts "Created: #{spokane.title} (#{spokane.id})"

  tacoma = Place.create!(
    {
      'title' => 'Tacoma',
      'county' => 'Pierce',
      'tags' => %w[wa city coast],
      'population' => 220_000
    },
    body: 'Tacoma is known for its port and Museum of Glass.'
  )
  puts "Created: #{tacoma.title} (#{tacoma.id})"

  puts "\n=== Querying Places ==="

  # Find all places
  all_places = Place.all.to_a
  puts "Total places: #{all_places.count}"

  # Query by county
  king_county_places = Place.all.in_county('King').to_a
  puts "\nPlaces in King County:"
  king_county_places.each do |place|
    puts "  - #{place.title} (pop: #{place['population']})"
  end

  # Query with tags
  coastal_places = Place.all.tagged('coast').to_a
  puts "\nCoastal places:"
  coastal_places.each do |place|
    puts "  - #{place.title}"
  end

  # Chain queries
  large_king_county = Place
                      .all
                      .in_county('King')
                      .where('population' => FMRepo.gt(200_000))
                      .order('population', :desc)
                      .to_a

  puts "\nLarge cities in King County:"
  large_king_county.each do |place|
    puts "  - #{place.title}: #{place['population']}"
  end

  # Find specific place
  puts "\n=== Finding by ID ==="
  found = Place.find('_places/seattle.md')
  puts "Found: #{found.title}"

  # Update a place
  puts "\n=== Updating ==="
  seattle['description'] = 'The Emerald City'
  seattle.body += "\n\nSeattle is also known as the Emerald City."
  seattle.save!
  puts "Updated #{seattle.title}"

  # Reload from disk
  seattle.reload
  puts "Reloaded #{seattle.title}: #{seattle['description']}"

  # Show file content
  puts "\n=== File Content ==="
  file_path = File.join(site_root, '_places', 'seattle.md')
  puts "Content of #{file_path}:"
  puts File.read(file_path)

  # Test collision resolution
  puts "\n=== Testing Collision Resolution ==="
  Place.create!({ 'title' => 'Seattle' }, body: 'Duplicate 1')
  puts 'Created _places/seattle-2.md'

  Place.create!({ 'title' => 'Seattle' }, body: 'Duplicate 2')
  puts 'Created _places/seattle-3.md'

  # Show all files created
  puts "\n=== All Created Files ==="
  Dir.glob(File.join(site_root, '_places', '*.md')).each do |file|
    puts "  #{File.basename(file)}"
  end

  # Demonstrate custom predicates
  puts "\n=== Custom Predicates ==="
  recent_large = Place
                 .all
                 .where('population' => FMRepo.between(200_000, 300_000))
                 .where('tags' => FMRepo.includes('city'))
                 .order('title')
                 .to_a

  puts 'Cities with population between 200K-300K:'
  recent_large.each do |place|
    puts "  - #{place.title}: #{place['population']}"
  end

  # Delete a place
  puts "\n=== Deleting ==="
  seattle.destroy
  puts "Deleted #{file_path}"
  puts "File exists: #{File.exist?(file_path)}"
ensure
  # Clean up
  FileUtils.rm_rf(site_root)
  puts "\n=== Cleanup Complete ==="
  puts 'Removed temporary directory'
end
