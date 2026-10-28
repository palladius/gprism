# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/gprism"

class TestGprismGem < Minitest::Test
  def setup
    @root = File.expand_path("..", __dir__)
  end

  def test_version_matches_version_file
    expected_version = File.read(File.join(@root, "VERSION")).strip
    assert_equal expected_version, Gprism::VERSION
    assert_equal expected_version, Gprism.version
  end

  def test_cli_version_flag
    out = `ruby -I#{@root}/lib #{@root}/bin/gprism --version`.strip
    expected_version = File.read(File.join(@root, "VERSION")).strip
    assert_equal "gprism #{expected_version}", out
  end

  def test_filter_secret_files
    files = [
      ".env",
      ".env.dist",
      ".env.template",
      ".env.local",
      "secret.txt",
      "secret.txt.gprenc",
      "secret.txt.readme"
    ]
    filtered = Gprism.filter_secret_files(files)
    assert_includes filtered, ".env"
    assert_includes filtered, ".env.local"
    assert_includes filtered, "secret.txt"
    refute_includes filtered, ".env.dist"
    refute_includes filtered, ".env.template"
    refute_includes filtered, "secret.txt.gprenc"
    refute_includes filtered, "secret.txt.readme"
  end

  def test_init_and_status
    g = Gprism.init
    assert_equal Gprism, g
    st = Gprism.status
    assert_equal Gprism::VERSION, st[:version]
  end

  def test_gemspec_validation
    gemspec_path = File.join(@root, "gprism.gemspec")
    assert File.exist?(gemspec_path), "gprism.gemspec should exist"

    spec = Gem::Specification.load(gemspec_path)
    refute_nil spec, "gemspec should load successfully"
    assert_equal "gprism", spec.name
    assert_equal Gprism::VERSION, spec.version.to_s
    assert_equal ["gprism"], spec.executables
    assert_includes spec.files, "VERSION"
    assert_includes spec.files, "README.md"
  end
end
