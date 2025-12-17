# frozen_string_literal: true

module FMRepo
  class ModelConfig
    attr_reader :glob, :exclude, :extensions, :naming_rule, :relation_class

    def initialize(glob: nil, exclude: nil, extensions: nil, naming_rule: nil, relation_class: nil)
      @glob = glob
      @exclude = Array(exclude).compact
      @extensions = extensions
      @naming_rule = naming_rule
      @relation_class = relation_class
    end

    def with(**kwargs)
      self.class.new(
        glob: kwargs.fetch(:glob, @glob),
        exclude: kwargs.fetch(:exclude, @exclude),
        extensions: kwargs.fetch(:extensions, @extensions),
        naming_rule: kwargs.fetch(:naming_rule, @naming_rule),
        relation_class: kwargs.fetch(:relation_class, @relation_class)
      )
    end
  end
end
