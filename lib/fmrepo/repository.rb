# frozen_string_literal: true

module FMRepo
  class Repository
    attr_reader :root

    def initialize(root:)
      @root = Pathname.new(root).expand_path
    end

    def glob(rel_glob)
      Dir.glob(@root.join(rel_glob)).map { |p| Pathname.new(p) }
    end

    def read(abs_path)
      assert_within_root!(abs_path)
      Pathname.new(abs_path).read
    end

    def write_atomic(abs_path, content)
      assert_within_root!(abs_path)
      abs = Pathname.new(abs_path)
      dir = abs.dirname
      FileUtils.mkdir_p(dir)

      tmp = dir.join("#{abs.basename}.tmp.#{Process.pid}.#{SecureRandom.hex(4)}")
      tmp.write(content)
      FileUtils.mv(tmp.to_s, abs.to_s)
    ensure
      FileUtils.rm_f(tmp.to_s) if tmp && tmp.exist?
    end

    def delete(abs_path)
      assert_within_root!(abs_path)
      FileUtils.rm_f(Pathname.new(abs_path).to_s)
    end

    def resolve_collision(rel_path)
      rel = Pathname.new(rel_path.to_s)
      abs = @root.join(rel)
      return rel unless abs.exist?

      base = rel.sub_ext("")
      ext = rel.extname
      i = 2
      loop do
        candidate = Pathname.new("#{base}-#{i}#{ext}")
        return candidate unless @root.join(candidate).exist?
        i += 1
      end
    end

    def abs(rel_path)
      @root.join(rel_path).expand_path
    end

    def rel(abs_path)
      Pathname.new(abs_path).expand_path.relative_path_from(@root)
    end

    def assert_within_root!(abs_path)
      abs = Pathname.new(abs_path).expand_path
      root_s = @root.to_s
      abs_s  = abs.to_s
      return if abs_s == root_s || abs_s.start_with?(root_s + File::SEPARATOR)
      raise UnsafePathError, "Path is outside repository root: #{abs}"
    end
  end
end
