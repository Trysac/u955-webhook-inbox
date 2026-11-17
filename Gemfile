# frozen_string_literal: true

# Factory-owned file: agents must not edit it. The library's own dependencies live in library.gemspec; this file adds
# the development tools, pinned by Gemfile.lock (`ruby scripts/add_dependency.rb --dev` adds one).
source "https://rubygems.org"

gemspec

group :development do
  gem "bundler-audit", "~> 0.9"
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.81"
  gem "rubocop-rspec", "~> 3.7"
  gem "simplecov", "~> 0.22"
  gem "yard", "~> 0.9"
end
