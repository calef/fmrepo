# frozen_string_literal: true

module FMRepo
  class Record
    class << self
      def config
        @config ||= ModelConfig.new(relation_class: FMRepo::Relation)
      end

      def scope(glob:, exclude: nil, extensions: nil)
        @config = config.with(glob: glob, exclude: exclude, extensions: extensions)
      end

      def naming(&block)
        raise ArgumentError, "naming requires a block" unless block
        @config = config.with(naming_rule: block)
      end

      def relation_class(klass = nil)
        if klass
          @config = config.with(relation_class: klass)
        else
          config.relation_class || FMRepo::Relation
        end
      end

      # Pattern A binding
      def bind(repo)
        @repo = repo
        self
      end

      def repo
        @repo
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

      def limit(n)
        relation.limit(n)
      end

      def offset(n)
        relation.offset(n)
      end

      def find(id)
        relation.find(id)
      end

      def find_by(criteria = {})
        relation.find_by(criteria)
      end

      def create!(attrs = {}, body: "", path: nil, repo: nil, **opts)
        rec = new(attrs, body: body, path: path, repo: (repo || self.repo), **opts)
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
        rec = new(fm, body: body, path: abs_path, repo: repo)
        rec.instance_variable_set(:@new_record, false)
        rec.instance_variable_set(:@dirty, false)
        rec.instance_variable_set(:@mtime, abs_path.exist? ? abs_path.mtime : nil)
        rec
      end

      def parse_front_matter(raw)
        s = raw.to_s
        return [{}, s] unless s.start_with?("---\n") || s.start_with?("---\r\n")

        lines = s.lines
        return [{}, s] unless lines.first&.strip == "---"

        i = 1
        while i < lines.length
          if ["---", "..."].include?(lines[i].strip)
            yaml_text = lines[1...i].join
            body_text = lines[(i + 1)..].join
            fm = yaml_text.strip.empty? ? {} : YAML.safe_load(yaml_text, permitted_classes: [Date, Time], aliases: true) || {}
            return [fm, body_text.sub(/\A\r?\n/, "")]
          end
          i += 1
        end

        raise ParseError, "Unclosed front matter delimiter"
      rescue Psych::Exception => e
        raise ParseError, "YAML parse error: #{e.message}"
      end
    end

    # ---- instance state ----
    attr_reader :repo, :path, :mtime
    attr_accessor :body

    def initialize(attrs = {}, body: "", path: nil, repo: nil, **_opts)
      @front_matter = normalize_keys(attrs || {})
      @body = body.to_s
      @repo = repo
      @path = path && Pathname.new(path.to_s)
      @new_record = true
      @dirty = true
      @mtime = nil
    end

    def front_matter
      @front_matter
    end

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
      raise NotFound, "Record has no path" unless @path
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
      yaml = fm.empty? ? "" : YAML.dump(fm).sub(/\A---\s*\r?\n/, "")
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
      hash.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v }
    end
  end
end
