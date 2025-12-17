# frozen_string_literal: true

module FMRepo
  class Relation
    include Enumerable

    SPECIAL_FIELD_READERS = {
      '_id' => lambda(&:id),
      '_path' => ->(rec) { rec.path&.to_s },
      '_rel_path' => ->(rec) { rec.rel_path&.to_s },
      '_mtime' => lambda(&:mtime),
      '_model' => ->(rec) { rec.class.name }
    }.freeze

    # rubocop:disable Metrics/ParameterLists
    def initialize(repo:, model:, filters: [], orders: [], limit_n: nil, offset_n: 0)
      @repo = repo
      @model = model
      @filters = filters
      @orders = orders
      @limit_n = limit_n
      @offset_n = offset_n
    end
    # rubocop:enable Metrics/ParameterLists

    attr_reader :repo, :model

    # ---- chaining ----
    def where(criteria = {})
      crit = normalize_keys(criteria)
      self.class.new(
        repo: @repo, model: @model,
        filters: @filters + [crit],
        orders: @orders,
        limit_n: @limit_n, offset_n: @offset_n
      )
    end

    def order(field, dir = :asc)
      self.class.new(
        repo: @repo, model: @model,
        filters: @filters,
        orders: @orders + [[field.to_s, (dir || :asc).to_sym]],
        limit_n: @limit_n, offset_n: @offset_n
      )
    end

    def limit(count)
      self.class.new(
        repo: @repo, model: @model, filters: @filters, orders: @orders,
        limit_n: Integer(count), offset_n: @offset_n
      )
    end

    def offset(count)
      self.class.new(
        repo: @repo, model: @model, filters: @filters, orders: @orders,
        limit_n: @limit_n, offset_n: Integer(count)
      )
    end

    # ---- execution ----
    def each(&) = to_a.each(&)

    def to_a
      docs = load_all
      docs = apply_filters(docs)
      docs = apply_orders(docs)
      apply_offset_limit(docs)
    end

    def first = limit(1).to_a.first
    def count = to_a.length

    def find(id)
      rel = Pathname.new(id.to_s)
      abs = @repo.abs(rel)
      raise NotFound, "No such file: #{rel}" unless abs.exist?

      @model.load_from_path(repo: @repo, abs_path: abs)
    end

    def find_by(criteria = {})
      where(criteria).first
    end

    private

    def load_all
      cfg = @model.config
      raise ArgumentError, "#{@model.name} has no scope glob" unless cfg.glob

      paths = @repo.glob(cfg.glob)
      paths = apply_excludes(paths, cfg.exclude)
      paths.map { |p| @model.load_from_path(repo: @repo, abs_path: p) }
    end

    def apply_excludes(paths, exclude_patterns)
      return paths if exclude_patterns.nil? || exclude_patterns.empty?

      paths.reject do |p|
        rel = @repo.rel(p).to_s
        exclude_patterns.any? { |pat| File.fnmatch?(pat, rel) }
      end
    end

    def apply_filters(records)
      @filters.reduce(records) { |acc, crit| acc.select { |rec| matches_criteria?(rec, crit) } }
    end

    def matches_criteria?(rec, crit)
      crit.all? do |key, expected|
        actual = value_for(rec, key)
        case expected
        when Proc then expected.call(actual)
        else actual == expected
        end
      end
    end

    def apply_orders(records)
      return records if @orders.empty?

      records.sort do |a, b|
        cmp = 0
        @orders.each do |(field, dir)|
          av = value_for(a, field)
          bv = value_for(b, field)
          cmp = compare_with_nil(av, bv)
          cmp = -cmp if dir == :desc
          break unless cmp.zero?
        end
        cmp
      end
    end

    def apply_offset_limit(records)
      out = records.drop(@offset_n)
      out = out.first(@limit_n) if @limit_n
      out
    end

    def value_for(rec, field)
      reader = SPECIAL_FIELD_READERS[field.to_s]
      return reader.call(rec) if reader

      rec.front_matter[field.to_s]
    end

    def compare_with_nil(left, right)
      return 0 if left.nil? && right.nil?
      return 1 if left.nil? # nil last for asc
      return -1 if right.nil?

      left <=> right
    rescue ArgumentError, NoMethodError
      left.to_s <=> right.to_s
    end

    def normalize_keys(hash)
      hash.transform_keys(&:to_s)
    end
  end
end
