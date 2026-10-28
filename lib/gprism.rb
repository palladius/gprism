# frozen_string_literal: true

require_relative "gprism/version"
require "yaml"
require "openssl"
require "digest"
require "fileutils"
require "shellwords"
require "base64"
require "open3"

module Gprism
  class Error < StandardError; end

  class << self
    attr_accessor :config_path, :environment, :project_id, :identity

    def version
      VERSION
    end

    def init(config = nil)
      @config_path = config || default_config_path
      load_config if File.exist?(@config_path)
      self
    end

    def default_config_path
      File.expand_path("~/.config/gprism/config.yaml")
    end

    def status(fix: false, verbose: false)
      {
        version: VERSION,
        config_path: @config_path,
        project_id: @project_id,
        identity: @identity
      }
    end

    # Filters out templates and encrypted artifacts when globbing secrets
    def filter_secret_files(files)
      ignored_suffixes = %w[.dist .template .example .sample .gprenc .readme]
      files.reject do |f|
        ignored_suffixes.any? { |sfx| f.end_with?(sfx) } || File.directory?(f)
      end
    end

    private

    def load_config
      return unless @config_path && File.exist?(@config_path)
      cfg = YAML.safe_load(File.read(@config_path)) rescue {}
      if cfg.is_a?(Hash)
        @project_id = cfg["project_id"]
        @identity = cfg["identity"]
      end
    end
  end
end
