# frozen_string_literal: true

module FMRepo
  class Record
    class << self
      def config
        @config ||= ModelConfig.new(relation_class: FMRepo::Relation)
      end

      def scope(glob:, exclude: nil, extensions: nil)
        @config = config.with(glob:, exclude:, extensions:)
      end

      def naming(&block)
        raise ArgumentError, 'naming requires a block' unless block

        @config = config.with(naming_rule: block)
      end

      def relation_class(klass = nil)
        if klass
          @config = config.with(relation_class: klass)
        else
          config.relation_class || FMRepo::Relation
        end
      end

      def repository_role(role = nil)
        if role
          @repository_role = role.to_sym
        else
          @repository_role || (superclass.respond_to?(:repository_role) ? superclass.repository_role : :default)
        end
      end

      # Repository configuration
      # Accepts either a path string or a Repository instance
      def repository(path_or_repo = nil)
        if path_or_repo
          @repo_config = path_or_repo
          @repository = nil # Clear cached repository when setting new config
          self
        elsif instance_variable_defined?(:@repo_config)
          # If a class-level repository was configured explicitly, cache it.
          @repository ||= build_repository_from(@repo_config)
        else
          # When using environment-driven repos, always ask the registry so overrides take effect.
          FMRepo.repository_registry.fetch(role: repository_role, environment: FMRepo.environment)
        end
      end

      def repo
        repository
      end

      # ---- ActiveRecord-ish class API ----
      def all
        relation
      end

      def where(criteria = {})
        relation.where(criteria)
      end

      def order(field, dir = :asc)
        relation.order(field, dir)
      end

      def limit(count)
        relation.limit(count)
      end

      def offset(count)
        relation.offset(count)
      end

      def find(id)
        relation.find(id)
      end

      def find_by(criteria = {})
        relation.find_by(criteria)
      end

      def create!(attrs = {}, body: '', path: nil, repo: nil, **)
        rec = new(attrs, body:, path:, repo: repo || self.repo, **)
        rec.save!
      end

      def relation(repo: nil)
        r = repo || self.repo
        raise NotBoundError, "#{name} is not bound to a repository" unless r

        relation_class.new(repo: r, model: self)
      end

      # ---- loading ----
      def load_from_path(repo:, abs_path:)
        raw = repo.read(abs_path)
        fm, body = parse_front_matter(raw)
        rec = new(fm, body:, path: abs_path, repo:)
        rec.instance_variable_set(:@new_record, false)
        rec.instance_variable_set(:@dirty, false)
        rec.instance_variable_set(:@mtime, abs_path.exist? ? abs_path.mtime : nil)
        rec
      end

      def parse_front_matter(raw)
        content = raw.to_s
        return [{}, content] unless front_matter_content?(content)

        lines = content.lines
        closing_index = front_matter_end_index(lines)
        raise ParseError, 'Unclosed front matter delimiter' unless closing_index

        yaml_text = lines[1...closing_index].join
        body_text = lines[(closing_index + 1)..].join
        fm = load_front_matter_yaml(yaml_text)

        [fm, strip_leading_newline(body_text)]
      rescue Psych::Exception => e
        raise ParseError, "YAML parse error: #{e.message}"
      end

      private

      def front_matter_content?(content)
        content.start_with?("---\n", "---\r\n") && content.lines.first&.strip == '---'
      end

      def front_matter_end_index(lines)
        index = lines[1..]&.find_index { |line| %w[--- ...].include?(line.strip) }
        index && (index + 1)
      end

      def load_front_matter_yaml(yaml_text)
        return {} if yaml_text.strip.empty?

        YAML.safe_load(yaml_text, permitted_classes: [Date, Time], aliases: false) || {}
      end

      def strip_leading_newline(text)
        text.sub(/\A\r?\n/, '')
      end

      def build_repository_from(config)
        case config
        when nil
          raise NotBoundError,
                "#{name} has no repository configured. Use `repository '/path/to/site'` in your class definition or configure " \
                "repositories for environment #{FMRepo.environment.inspect}."
        when FMRepo::Repository
          config
        when String, Pathname
          FMRepo::Repository.new(root: config)
        else
          raise ArgumentError,
                "repository must be a path string or Repository instance, got #{config.class}"
        end
      end
    end

    # ---- instance state ----
    attr_reader :repo, :path, :mtime
    attr_accessor :body

    def initialize(attrs = {}, body: '', path: nil, repo: nil, **_opts)
      @front_matter = normalize_keys(attrs || {})
      @body = body.to_s
      @repo = repo
      @path = path && Pathname.new(path.to_s)
      @new_record = true
      @dirty = true
      @mtime = nil
    end

    attr_reader :front_matter

    def [](key) = @front_matter[key.to_s]

    def []=(key, value)
      @front_matter[key.to_s] = value
      @dirty = true
    end

    def id
      return nil unless @repo && @path

      @repo.rel(@path).to_s
    end

    def rel_path
      return nil unless @repo && @path

      @repo.rel(@path)
    end

    def new_record?
      @new_record
    end

    def persisted?
      !@new_record
    end

    def save!
      ensure_repo!
      ensure_path!
      @repo.write_atomic(@path, serialize)
      @mtime = @path.exist? ? @path.mtime : nil
      @dirty = false
      @new_record = false
      self
    end

    def destroy
      ensure_repo!
      return self unless @path

      @repo.delete(@path)
      self
    end

    def reload
      ensure_repo!
      raise NotFound, 'Record has no path' unless @path

      fresh = self.class.load_from_path(repo: @repo, abs_path: @path)
      @front_matter = fresh.front_matter
      @body = fresh.body
      @mtime = fresh.mtime
      @dirty = false
      @new_record = false
      self
    end

    def serialize
      fm = @front_matter || {}
      # Sort keys alphabetically to minimize diff sizes
      sorted_fm = fm.sort.to_h
      yaml = sorted_fm.empty? ? '' : YAML.dump(sorted_fm).sub(/\A---\s*\r?\n/, '')
      out = +"---\n"
      out << yaml
      out << "\n" unless out.end_with?("\n")
      out << "---\n\n"
      out << @body.to_s
      out << "\n" unless out.end_with?("\n")
      out
    end

    private

    def ensure_repo!
      @repo ||= self.class.repo
      raise NotBoundError, "#{self.class.name} is not bound to a repository" unless @repo
    end

    def ensure_path!
      return if @path

      rule = self.class.config.naming_rule
      raise ArgumentError, "#{self.class.name} has no naming rule and no path was provided" unless rule

      rel = rule.call(front_matter: @front_matter, body: @body, repo: @repo)
      rel = Pathname.new(rel.to_s)
      rel = @repo.resolve_collision(rel)
      @path = @repo.abs(rel)
    end

    def normalize_keys(hash)
      hash.transform_keys(&:to_s)
    end
  end
end
