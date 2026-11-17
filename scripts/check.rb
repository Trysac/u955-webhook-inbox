# frozen_string_literal: true

# Runs every quality gate of this repository, in order, stopping at the first failure.
#
# Usage: `ruby scripts/check.rb` (the same command locally, in the factory and in CI); append gate names to run only
# those, in the standard order. Run `bundle install` first.
#
# Gates: format (RuboCop's Layout cops); lint (`gem build --strict` of library.gemspec, then RuboCop with every other
# cop, offenses fail); semgrep (Semgrep CE with the factory's own rules in .semgrep/); tests (RSpec under SimpleCov)
# with line coverage >= 80 % of lib/; docs: the documentation manifest plus YARD with every public module, class,
# constant and method of lib/ documented; secrets (gitleaks); audit (bundler-audit over Gemfile.lock, the Ruby
# Advisory Database, any advisory fails) and OSV-Scanner over Gemfile.lock (high severity). No shell: it runs every
# tool with an argument list, so it behaves the same on Windows and Linux. Factory-owned file: agents must not edit it.

require "English"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

# The quality gates of this repository.
module Check
  MIN_COVERAGE = 80.0
  DOCS_MANIFEST = "docs-manifest.json"
  ALLOW_MISSING_GITLEAKS = "FABRICA_ALLOW_MISSING_GITLEAKS"
  ALLOW_OFFLINE_AUDIT = "FABRICA_ALLOW_OFFLINE_AUDIT"
  # FABRICA_CI=1 also runs the examples tagged `:conformance` (external tools or downloads); only the CI conformance
  # job sets it, so local gates and coverage skip them.
  CI_TIER = "FABRICA_CI"
  CONFORMANCE_TAG = "conformance"
  # The factory's own Semgrep rules; Semgrep-maintained rules are never used (license).
  SEMGREP_RULES = ".semgrep/factory-rules.yml"
  LOCK_FILE = "Gemfile.lock"
  GEMSPEC = "library.gemspec"
  HIGH_CVSS = 7.0
  # osv-scanner's exit codes: 1 when vulnerabilities were found, 128 when no package was found.
  OSV_FOUND = 1
  OSV_NO_PACKAGES = 128
  GATES = %w[format lint semgrep tests docs secrets audit osv].freeze

  module_function

  def main(args)
    unless File.file?("Gemfile") && File.file?("scripts/check.rb")
      warn "check: run from the repository root (Gemfile not found)"
      return 2
    end
    unknown = args.reject { |name| GATES.include?(name) }
    unless unknown.empty?
      warn "check: unknown gate \"#{unknown.first}\""
      return 2
    end
    GATES.each do |name|
      next unless args.empty? || args.include?(name)

      puts "==> #{name}"
      $stdout.flush
      error = send(:"#{name}_gate")
      if error
        warn "#{name}: #{error}"
        warn "==> #{name}: FAILED"
        return 1
      end
      puts "==> #{name}: ok"
    end
    puts "==> all gates passed"
    0
  end

  def flag?(name)
    ENV.fetch(name, nil) == "1"
  end

  # The program's path when it is on PATH (with the Windows executable suffixes).
  def which(program)
    suffixes = Gem.win_platform? ? [".exe", ".bat", ".cmd", ""] : [""]
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
      suffixes.each do |suffix|
        candidate = File.join(dir.empty? ? "." : dir, "#{program}#{suffix}")
        return candidate if File.file?(candidate)
      end
    end
    nil
  end

  # Runs a program without a shell; returns nil when it succeeds, else the reason it failed.
  def run(argv, env = {})
    ok = system(env, *argv, exception: false)
    return nil if ok

    "`#{argv.join(" ")}` failed (#{ok.nil? ? "cannot start it" : "exit #{$CHILD_STATUS.exitstatus}"})"
  end

  # Runs a program without a shell and returns its exit code and stdout (stderr goes to the terminal).
  def capture(argv, env = {})
    stdout, status = Open3.capture2(env, *argv)
    [status.exitstatus, stdout]
  rescue SystemCallError => e
    [127, e.message]
  end

  # A command run through Bundler with this Ruby, so the tools are the ones Gemfile.lock pins.
  def bundled(*args)
    [RbConfig.ruby, "-S", "bundle", "exec", *args]
  end

  def format_gate
    error = run(bundled("rubocop", "--only", "Layout", "--format", "simple", "--display-cop-names"))
    return "#{error}: run `bundle exec rubocop --autocorrect --only Layout`" if error

    puts "rubocop: every file follows the layout rules"
    nil
  end

  # The gemspec builds without warnings, then RuboCop with every cop but Layout (the format gate).
  def lint_gate
    Dir.mktmpdir("fabrica-ruby-gem") do |dir|
      error = run([RbConfig.ruby, "-S", "gem", "build", GEMSPEC, "--strict", "--quiet", "--output",
                   File.join(dir, "library.gem")])
      return "#{error}: #{GEMSPEC} is invalid" if error
    end
    error = run(bundled("rubocop", "--except", "Layout", "--format", "simple", "--display-cop-names"))
    return error if error

    puts "gem build --strict and RuboCop: no offenses"
    nil
  end

  # Semgrep CE with the factory's own rules only; ERROR rules fail and nosemgrep comments are ignored. Specs,
  # scripts/ and vendor/ are not scanned.
  def semgrep_gate
    exe = which("semgrep")
    return missing_scanner("semgrep") unless exe

    run([exe, "scan", "--config", SEMGREP_RULES, "--error", "--severity", "ERROR", "--metrics", "off",
         "--disable-version-check", "--disable-nosem", "--quiet", "--exclude=scripts", "--exclude=spec",
         "--exclude=vendor", "."])
  end

  def build_dir
    base = ENV.fetch("FABRICA_BUILD_DIR", "")
    File.join(base.empty? ? Dir.tmpdir : base, "fabrica-ruby-check-#{Process.pid}")
  end

  def tests_gate
    dir = build_dir
    FileUtils.rm_rf(dir)
    args = ["rspec", "--require", "./scripts/coverage.rb"]
    if flag?(CI_TIER)
      puts "tests: CI tier, the conformance examples run too"
    else
      args += ["--tag", "~#{CONFORMANCE_TAG}"]
    end
    error = run(bundled(*args), { "FABRICA_COVERAGE_DIR" => dir })
    return error if error

    last_run = File.join(dir, ".last_run.json")
    return "SimpleCov wrote no coverage report (#{last_run})" unless File.file?(last_run)

    total = JSON.parse(File.read(last_run)).dig("result", "line")
    FileUtils.rm_rf(dir)
    return "the coverage report has no lines" unless total.is_a?(Numeric)

    puts format("Total coverage: %<total>.2f%%", total: total)
    if total < MIN_COVERAGE
      return format("total line coverage %<total>.1f%% is below %<min>.0f%%", total: total, min: MIN_COVERAGE)
    end

    puts format("tests: line coverage %<total>.1f%% (minimum %<min>.0f%%)", total: total, min: MIN_COVERAGE)
    nil
  end

  def count_lines(text)
    trimmed = text.gsub("\r\n", "\n").sub(/\n+\z/, "")
    trimmed.empty? ? 0 : trimmed.count("\n") + 1
  end

  def string_list(value)
    value.is_a?(Array) ? value.grep(String) : []
  end

  # Every violation of docs-manifest.json; an empty list means the manifest part of the docs gate passes.
  def manifest_errors(manifest)
    errors = []
    string_list(manifest["required"]).each do |rel|
      if !File.file?(rel)
        errors << "missing required file: #{rel}"
      elsif File.read(rel).strip.empty?
        errors << "required file is empty: #{rel}"
      end
    end
    string_list(manifest["required_globs"]).each do |pattern|
      errors << "no file matches required pattern: #{pattern}" if Dir.glob(pattern).none? { |f| File.file?(f) }
    end
    limits = manifest["max_lines"].is_a?(Hash) ? manifest["max_lines"] : {}
    limits.each do |rel, max|
      next unless File.file?(rel) && max.is_a?(Integer)

      lines = count_lines(File.read(rel))
      errors << "#{rel} has #{lines} lines (max #{max})" if lines > max
    end
    references = manifest["must_reference"].is_a?(Hash) ? manifest["must_reference"] : {}
    references.each do |rel, needle|
      next unless File.file?(rel) && needle.is_a?(String)

      errors << "#{rel} must reference #{needle}" unless File.read(rel).include?(needle)
    end
    errors
  end

  # YARD over lib/: every public module, class, constant and method has a docstring.
  def api_doc_errors
    code, out = capture(bundled("yard", "stats", "--list-undoc", "--no-save", "--no-cache", "--no-progress",
                                "lib/**/*.rb"))
    return ["`yard stats` failed (exit #{code})"] unless code.zero?

    return [] if out.include?("100.00% documented")

    out.lines.map(&:strip).reject(&:empty?).map { |line| "yard: #{line}" }
  end

  def docs_gate
    return "#{DOCS_MANIFEST} not found" unless File.file?(DOCS_MANIFEST)

    begin
      manifest = JSON.parse(File.read(DOCS_MANIFEST))
    rescue JSON::ParserError => e
      return "#{DOCS_MANIFEST} is not valid JSON: #{e.message}"
    end
    errors = manifest_errors(manifest.is_a?(Hash) ? manifest : {}) + api_doc_errors
    errors.each { |error| warn "docs: #{error}" }
    return "#{errors.size} documentation problem(s)" unless errors.empty?

    puts "docs: every file in #{DOCS_MANIFEST} is present and the public API is documented"
    nil
  end

  def secrets_gate
    exe = which("gitleaks")
    unless exe
      if flag?(ALLOW_MISSING_GITLEAKS)
        puts "gitleaks: SKIPPED (not installed)"
        return nil
      end
      return "FAIL - gitleaks is not installed. Install it (https://github.com/gitleaks/gitleaks#installing), e.g. " \
             "`winget install Gitleaks.Gitleaks`, `brew install gitleaks` or a release binary, or set " \
             "#{ALLOW_MISSING_GITLEAKS}=1 to skip this gate locally."
    end
    run([exe, "dir", ".", "--redact", "--verbose", "--no-banner"])
  end

  # A scanner that is not installed: skipped locally, a failure in CI (FABRICA_CI=1).
  def missing_scanner(tool)
    return "#{tool} not installed (required when #{CI_TIER}=1)" if flag?(CI_TIER)

    puts "#{tool}: skipped: #{tool} not installed"
    nil
  end

  # Every gem of Gemfile.lock (runtime and development) against the Ruby Advisory Database; any advisory fails, like
  # pip-audit or npm audit. Updating the database needs the network; FABRICA_ALLOW_OFFLINE_AUDIT=1 skips the gate
  # when it is unreachable.
  def audit_gate
    code, = capture(bundled("bundle-audit", "update", "--quiet"))
    unless code.zero?
      if flag?(ALLOW_OFFLINE_AUDIT)
        puts "audit: SKIPPED (the Ruby Advisory Database is unreachable)"
        return nil
      end
      return "`bundle-audit update` failed (exit #{code}), or set #{ALLOW_OFFLINE_AUDIT}=1 to skip this gate offline"
    end
    error = run(bundled("bundle-audit", "check", "--gemfile-lock", LOCK_FILE))
    return "#{error}: known vulnerabilities in the locked gems" if error

    puts "audit: no known vulnerabilities in the locked gems"
    nil
  end

  # The advisory groups with CVSS >= 7.0 or no score (unknown counts as high).
  def osv_blocking(report)
    Array(report["results"]).flat_map do |result|
      Array(result.is_a?(Hash) ? result["packages"] : nil).flat_map do |package|
        info = package.is_a?(Hash) && package["package"].is_a?(Hash) ? package["package"] : {}
        groups = package.is_a?(Hash) ? Array(package["groups"]) : []
        groups.filter_map do |group|
          severity = group.is_a?(Hash) ? group["max_severity"].to_s.strip : ""
          known = severity.match?(/\A\d+(\.\d+)?\z/)
          next if known && severity.to_f < HIGH_CVSS

          ids = string_list(group.is_a?(Hash) ? group["ids"] : nil).join(",")
          "#{info["name"]}@#{info["version"]} #{ids} (#{known ? severity : "unknown"})"
        end
      end
    end
  end

  # OSV-Scanner over Gemfile.lock (RubyGems is an OSV ecosystem); high or unknown severity fails.
  def osv_gate
    exe = which("osv-scanner")
    return missing_scanner("osv-scanner") unless exe

    code, out = capture([exe, "scan", "source", "--format", "json", "--lockfile=#{LOCK_FILE}"])
    case code
    when 0
      puts "osv-scanner: no known vulnerabilities in #{LOCK_FILE}"
      return nil
    when OSV_NO_PACKAGES
      puts "osv-scanner: no packages in #{LOCK_FILE}"
      return nil
    when OSV_FOUND
      nil
    else
      return "osv-scanner failed (exit #{code})"
    end
    begin
      report = JSON.parse(out)
    rescue JSON::ParserError
      return "osv-scanner: unreadable JSON report"
    end
    blocking = osv_blocking(report.is_a?(Hash) ? report : {})
    blocking.each { |line| warn "osv-scanner: #{line}" }
    return "#{blocking.size} advisory group(s) of high or unknown severity" unless blocking.empty?

    puts "osv-scanner: only advisories below high severity (reported, not failing)"
    nil
  end
end

exit(Check.main(ARGV)) if $PROGRAM_NAME == __FILE__
