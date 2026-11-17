# frozen_string_literal: true

# Factory-owned file: agents must not edit it. The gem's runtime dependencies are added by
# `ruby scripts/add_dependency.rb`; its version lives in lib/trysac/webhook_inbox/version.rb (the release manager).
#
# The version is read from the file, not required: Bundler evaluates this gemspec before SimpleCov starts, and a
# required version.rb would count as uncovered.
Gem::Specification.new do |spec|
  spec.name = "u955-webhook-inbox"
  spec.version = File.read(File.join(__dir__, "lib/trysac/webhook_inbox/version.rb"))[/^\s*VERSION = "([^"]+)"$/, 1]
  spec.authors = ["Miguel Gomez"]
  spec.summary = <<~SUMMARY.strip
    Rack webhook inbox that captures, inspects and forwards requests with byte-exact bodies and preserved headers, signed with Standard Webhooks HMAC-SHA256 signatures
  SUMMARY
  # `gem build --strict` (the lint gate) warns when the description repeats the summary.
  spec.description = "#{spec.summary} A Ruby library built by the Trysac software factory."
  spec.homepage = "https://github.com/Trysac/u955-webhook-inbox"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0"

  spec.metadata["source_code_uri"] = "https://github.com/Trysac/u955-webhook-inbox"
  spec.metadata["changelog_uri"] = "https://github.com/Trysac/u955-webhook-inbox/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "CHANGELOG.md", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]
end
