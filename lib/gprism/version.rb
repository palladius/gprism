# frozen_string_literal: true

module Gprism
  VERSION_FILE = File.expand_path("../../VERSION", __dir__)
  VERSION = File.exist?(VERSION_FILE) ? File.read(VERSION_FILE).strip : "0.3.9"
end
