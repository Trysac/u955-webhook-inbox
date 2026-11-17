# frozen_string_literal: true

# Starts SimpleCov before RSpec loads the library (`rspec --require ./scripts/coverage.rb`, run by scripts/check.rb).
# Line coverage of lib/ only; every file of lib/ counts, loaded or not. The report goes to FABRICA_COVERAGE_DIR (a
# temporary folder chosen by check.rb), never into the repository. Factory-owned file: agents must not edit it.

require "simplecov"

SimpleCov.root(Dir.pwd)
SimpleCov.coverage_dir(ENV.fetch("FABRICA_COVERAGE_DIR", "coverage"))
SimpleCov.formatter = SimpleCov::Formatter::SimpleFormatter
SimpleCov.print_error_status = false
# `# :nocov:` must not hide code from the threshold: the marker is replaced by one no file contains.
SimpleCov.nocov_token("fabrica-nocov-is-not-honoured")
SimpleCov.start do
  enable_coverage :line
  track_files "lib/**/*.rb"
  add_filter %r{\A/(?!lib/)}
end
