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
  # @return [Hash{String => String}]
  def call
    with_env do |env|
      configure(env: env)
      dotenv(env: env)
      serve(env: env)
    end
  end

  class << self
    # @return [Hash{String => String}]
    def call
      self.new.call
    end
  end

  protected

  # Give defaults or given env.
  #
  # @param env [Hash{String => String}]
  #
  # @return [Hash{String => String,Proc}]
  def defaults_from(env)
    {
      SERVE_ENV: 'development',
      SERVE_WITH_CLEAN_ENV: 'on',
      SERVE_CONFIG_COPY: 'on',
      SERVE_CONFIG_PATH: fs.pwd,
      SERVE_CONFIG_FILE: -> { "Passengerfile.#{env['SERVE_ENV']}.json" },
      SERVE_DOTENV_LOAD: 'on',
      SERVE_DOTENV_FILE: '.env',
      SERVE_DOTENV_PATH: fs.pwd,
    }.transform_keys(&:to_s)
  end

  # @return [Module<FileUtils>]
  def fs
    autoload(:FileUtils, 'fileutils')
      .then { FileUtils }
  end

  # @return [Pathname]
  def path(path = nil)
    path ||= ::File.realpath(fs.pwd)

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
  def with_env(actual_env = ENV, &block)
    env_defaults = defaults_from(actual_env.to_h)

    actual_env.to_h.clone.tap do |env|
      env_defaults.each do |k, v|
        if actual_env[k].to_s.empty?
          (v.is_a?(Proc) ? v.call : v.to_s).then { env[k] = _1 }
        end
      end
    end.reject { _2.to_s.empty? }.map do |k, v|
      [k, /_(COPY|LOAD)$/ =~ k.to_s ? v.to_s.downcase : v]
    end.to_h.freeze.then do |env|
      if on?(actual_env['SERVE_WITH_CLEAN_ENV'])
        clean_env(actual_env: actual_env, keys: env_defaults.keys)
      else
        actual_env.merge!(env)
      end

      block ? block.call(env) : env
    end
  end

  # Clean given env with given keys.
  #
  # @param actual_env [Hash{String => String}, Class<ENV>]
  # @param keys [Array<String>]
  #
  # @return [Hash{String => String}]
  def clean_env(actual_env: ENV, keys: [])
    keys.map do |key|
      [key, actual_env.delete(key)]
    end.to_h
  end

  # Load dotenv (with given env).
  #
  # @param env [Hash{String => String}]
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
  # @param env [Hash{String => String}]
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
  # @param env [Hash{String => String}]
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
