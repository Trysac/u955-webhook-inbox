# frozen_string_literal: true

# Adds one gem dependency for the factory: `ruby scripts/add_dependency.rb [--dev] <gem> [<spec>]`.
#
# The spec is the allowed range of the item (empty, an exact version, `==x`, `>=x` or `>=x,<y`); it is written as
# given (`==x` becomes `= x`, each comma part one requirement): a runtime dependency to library.gemspec
# (`spec.add_dependency`, which consumers of the gem resolve), a `--dev` one to the Gemfile's development group. Then
# `bundle lock` pins the newest release inside the range in Gemfile.lock and `bundle install` installs it. When either
# fails, the Gemfile, the gemspec and the lock are restored. No shell: Bundler runs with an argument list.
# Factory-owned file: agents must not edit it.

require "fileutils"
require "rbconfig"
require "rubygems"

# Adds a dependency to library.gemspec or the Gemfile and relocks.
module AddDependency
  GEMSPEC = "library.gemspec"
  GEMFILE = "Gemfile"
  LOCK = "Gemfile.lock"
  # RubyGems' gem name rule.
  GEM_NAME = /\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/
  USAGE = "usage: ruby scripts/add_dependency.rb [--dev] <gem> [<spec>]"

  module_function

  def main(args)
    dev = false
    positional = []
    args.each do |arg|
      if arg == "--dev"
        dev = true
      elsif arg == "--git"
        warn "add_dependency: factory repositories are not installable in Ruby yet (no RubyGems release)"
        return 1
      elsif arg.start_with?("--")
        warn "add_dependency: unknown option #{arg}"
        return 2
      else
        positional << arg
      end
    end
    return usage unless [1, 2].include?(positional.size)

    name, spec = positional
    unless GEM_NAME.match?(name)
      warn "add_dependency: #{name} is not a gem name"
      return 2
    end
    requirements = parse(spec.to_s)
    return 2 unless requirements

    add(name, requirements, dev)
  end

  def usage
    warn USAGE
    2
  end

  # The requirements of a spec as written (`==x` is `= x`); nil after reporting an invalid one.
  def parse(spec)
    parts = spec.split(",").map(&:strip).reject(&:empty?).map { |part| part.sub(/\A==\s*/, "= ") }
    parts.each { |part| Gem::Requirement.parse(part) }
    parts
  rescue Gem::Requirement::BadRequirementError => e
    warn "add_dependency: #{e.message}"
    nil
  end

  def declaration(name, requirements)
    [name, *requirements].map { |item| %("#{item}") }.join(", ")
  end

  # The file text with the dependency line inserted, or nil when there is no place for it.
  def inserted(text, name, requirements, dev)
    if dev
      anchor = text.index(/^group :development do\n/)
      return nil unless anchor

      at = text.index("\n", anchor) + 1
      return "#{text[0...at]}  gem #{declaration(name, requirements)}\n#{text[at..]}"
    end
    at = text.rindex(/^end\s*\z/)
    return nil unless at

    "#{text[0...at]}\n  spec.add_dependency #{declaration(name, requirements)}\n#{text[at..]}"
  end

  def bundle(*)
    system({ "BUNDLE_FROZEN" => "false" }, RbConfig.ruby, "-S", "bundle", *, exception: false)
  end

  def add(name, requirements, dev)
    path = dev ? GEMFILE : GEMSPEC
    saved = [GEMFILE, GEMSPEC, LOCK].to_h { |file| [file, File.file?(file) ? File.binread(file) : nil] }
    text = inserted(File.read(path), name, requirements, dev)
    unless text
      warn "add_dependency: #{path} has no place for a dependency"
      return 1
    end
    File.write(path, text)
    return 0 if bundle("lock") && bundle("install")

    saved.each { |file, content| content ? File.binwrite(file, content) : FileUtils.rm_f(file) }
    warn "add_dependency: `bundle lock` or `bundle install` failed; #{path} and #{LOCK} were restored"
    1
  end
end

exit(AddDependency.main(ARGV)) if $PROGRAM_NAME == __FILE__
