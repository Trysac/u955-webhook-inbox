# frozen_string_literal: true

require "optparse"
require "json"

module Trysac
  module WebhookInbox
    # Command-line interface for signing and verifying Standard Webhooks payloads.
    module CLI
      # Text-valued `verify` options and the option key each one sets.
      VERIFY_TEXT_FLAGS = {
        "--secret SECRET" => :secret, "--id ID" => :id, "--timestamp TS" => :timestamp,
        "--signature SIG" => :signature, "--body BODY" => :body
      }.freeze
      private_constant :VERIFY_TEXT_FLAGS

      # Runs the CLI with the given argument vector and output streams.
      #
      # @param argv [Array<String>] command-line arguments
      # @param stdout [IO] standard output stream
      # @param stderr [IO] standard error stream
      # @return [Integer] exit code (0 = ok, 1 = domain failure, 2 = usage/IO/parse error)
      def self.run(argv, stdout: $stdout, stderr: $stderr)
        args = Array(argv).dup
        cmd = args.shift
        dispatch_command(cmd, args, stdout, stderr)
      rescue OptionParser::ParseError, Errno::ENOENT, Errno::EACCES, IOError => e
        stderr.puts("Error: #{e.message}")
        2
      rescue Error => e
        stderr.puts(JSON.generate({ "code" => e.code.to_s, "error" => e.message }))
        1
      end

      def self.dispatch_command(cmd, args, stdout, stderr)
        case cmd
        when "sign" then run_sign(args, stdout, stderr)
        when "verify" then run_verify(args, stdout, stderr)
        when "-h", "--help", "help" then print_usage(stdout)
                                         0
        when "-v", "--version", "version" then stdout.puts(Trysac::WebhookInbox::VERSION)
                                               0
        else print_usage(stderr)
             2
        end
      end

      def self.parse_sign_opts(args)
        options = { timestamp: Time.now.to_i }
        OptionParser.new do |opts|
          opts.on("--secret SECRET") { |v| options[:secret] = v }
          opts.on("--id ID") { |v| options[:id] = v }
          opts.on("--timestamp TS", Integer) { |v| options[:timestamp] = v }
          opts.on("--body BODY") { |v| options[:body] = v }
        end.parse!(args)
        options
      end

      def self.run_sign(args, stdout, stderr)
        opts = parse_sign_opts(args)
        if opts[:secret].nil? || opts[:id].nil? || opts[:body].nil?
          stderr.puts("Usage: webhook-inbox sign --secret SECRET --id ID --body BODY [--timestamp TS]")
          return 2
        end
        stdout.puts(Signer.sign(secret: opts[:secret], id: opts[:id], timestamp: opts[:timestamp], body: opts[:body]))
        0
      end

      def self.parse_verify_opts(args)
        options = { now: Time.now.to_i, tolerance: Signer::DEFAULT_TOLERANCE }
        OptionParser.new do |opts|
          VERIFY_TEXT_FLAGS.each { |flag, key| opts.on(flag) { |v| options[key] = v } }
          opts.on("--now NOW", Integer) { |v| options[:now] = v }
          opts.on("--tolerance SEC", Integer) { |v| options[:tolerance] = v }
        end.parse!(args)
        options
      end

      def self.verify_args_valid?(opts)
        opts[:secret] && opts[:id] && opts[:timestamp] && opts[:signature] && opts[:body]
      end

      def self.run_verify(args, stdout, stderr)
        opts = parse_verify_opts(args)
        unless verify_args_valid?(opts)
          stderr.puts("Usage: webhook-inbox verify --secret SECRET --id ID --timestamp TS --signature SIG --body BODY")
          return 2
        end
        Signer.verify(secret: opts[:secret], headers: verify_headers(opts), body: opts[:body], now: opts[:now],
                      tolerance: opts[:tolerance])
        stdout.puts("verified")
        0
      end

      def self.verify_headers(opts)
        { "webhook-id" => opts[:id], "webhook-timestamp" => opts[:timestamp], "webhook-signature" => opts[:signature] }
      end

      def self.print_usage(io)
        io.puts(<<~USAGE)
          Usage: webhook-inbox <command> [options]
          Commands:
            sign    --secret SECRET --id ID --body BODY [--timestamp TS]
            verify  --secret SECRET --id ID --timestamp TS --signature SIG --body BODY [--now NOW] [--tolerance SEC]
            version
            help
        USAGE
      end

      private_class_method :run_sign, :run_verify, :print_usage,
                           :dispatch_command, :parse_sign_opts, :parse_verify_opts, :verify_args_valid?,
                           :verify_headers
    end
  end
end
