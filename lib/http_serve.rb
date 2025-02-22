# frozen_string_literal: true

File.realpath(__FILE__).then { File.dirname(_1) }.then do |lib_dir|
  $: << lib_dir unless $:.include?(lib_dir)
end

# Provides a simple wrapper on top of Phusion Passenger(R)
#
# Sample of use:
#
#   File.realpath("#{__dir__}/..").then { Dir.chdir(_1) }
#   require 'bundler/setup'
#   require 'http_serve'
#   HttpServe.call
class HttpServe
  def call
    with_env do |env|
      configure(env: env)
      dotenv(env: env)
      serve(env: env)
    end
  end

  class << self
    def call
      self.new.call
    end
  end

  protected

  # @return [Module<FileUtils>]
  def fs
    autoload(:FileUtils, 'fileutils')
      .then { FileUtils }
  end

  # @return [Pathname]
  def path(path = nil)
    path ||= ::File.realpath(Dir.pwd)

    autoload(:Pathname, 'pathname')
      .then { Pathname.new(path) }
  end

  # Denotes given value is in <tt>[on true yes]</tt>.
  #
  # @return [Boolean]
  def on?(v)
    %w[on true yes].include?(v.to_s)
  end

  # Process with given environment.
  #
  # @yieldparam [Hash{String => String}]
  #
  # @return [Hash{String => String}, Object]
  def with_env(actual_env = ENV.to_h, &block)
    actual_env.to_h.clone.tap do |env|
      {
        SERVE_ENV: 'development',
        SERVE_CONFIG_COPY: 'on',
        SERVE_CONFIG_PATH: Dir.pwd,
        SERVE_CONFIG_FILE: -> { "Passengerfile.#{env['SERVE_ENV']}.json" },
        SERVE_DOTENV_LOAD: 'on',
        SERVE_DOTENV_FILE: '.env',
        SERVE_DOTENV_PATH: Dir.pwd,
      }.transform_keys(&:to_s).each do |k, v|
        if actual_env[k].to_s.empty?
          (v.is_a?(Proc) ? v.call : v.to_s).then { env[k] = _1 }
        end
      end
    end.reject { _2.to_s.empty? }.map do |k, v|
      [k, /_(COPY|LOAD)$/ =~ k.to_s ? v.to_s.downcase : v]
    end.to_h.freeze.then do |env|
      block ? block.call(env) : env
    end
  end

  # Load dotenv (with given env).
  def dotenv(env: ENV.to_h)
    return unless on?(env['SERVE_DOTENV_LOAD'])

    autoload(:Dotenv, 'dotenv').then do
      path(env['SERVE_DOTENV_PATH'])
        .join(env['SERVE_DOTENV_FILE'])
        .then { |file| Dotenv.load(file.to_s) }
    rescue LoadError => e
      $stderr.puts("#{e.class}: #{e.message}")
    end
  end

  # Copy original config.
  #
  # @see https://www.phusionpassenger.com/library/config/standalone/reference/
  def configure(env: ENV.to_h)
    path('Passengerfile.json').tap do |file|
      on?(env['SERVE_CONFIG_COPY']).then do |flag|
        (flag ? true : env['SERVE_CONFIG_COPY'] == 'force').then do |v|
          v || v == 'force' ? true : v == 'force' and !file.file?
        end
      end.then { return unless _1 }

      path(env['SERVE_CONFIG_PATH'])
        .join(env['SERVE_CONFIG_FILE'])
        .then { fs.cp(_1, file) }
    end
  end

  # Run standalone web server
  #
  # @see https://github.com/phusion/passenger/blob/stable-6.0/bin/passenger
  def serve(env: ENV.to_h, argv: ARGV)
    version_cname = :VERSION_STRING
    end_boot_regexp = /^#+\s+Magic comment: end bootstrap\s+#+\s*$/

    argv.push('start') if argv.empty?
    require('phusion_passenger/rack_handler').then do
      if argv[0] == 'start' and PhusionPassenger.const_defined?(version_cname, false)
        puts 'Starting Phusion Passenger(R) %<version>s [%<environment>s]' % {
          version: PhusionPassenger.const_get(version_cname),
          environment: env['SERVE_ENV'],
        }
      end
    end

    PhusionPassenger.locate_directories.then do
      path(PhusionPassenger.bin_dir).join('passenger').then do |script_file|
        (script_file.read)
          .split(end_boot_regexp)
          .fetch(1)
          .strip
          .tap { self.instance_eval(_1, __FILE__, 0) }
      end
    end
  end
end
