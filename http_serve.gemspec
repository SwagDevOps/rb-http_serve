# frozen_string_literal: true

# vim: ai ts=2 sts=2 et sw=2 ft=ruby
# rubocop:disable all

# noinspection RubyLiteralArrayInspection
Gem::Specification.new do |s|
  s.name        = "http_serve"
  s.version     = "0.0.1"
  s.date        = "2025-02-22"
  s.summary     = "Wrapper built on top of Phusion Passenger(R)"

  s.authors     = ["Dimitri Arrigoni"]
  s.email       = "dimitri@arrigoni.me"
  s.homepage    = "https://github.com/SwagDevOps/rb-http_serve"

  s.required_ruby_version = ">= 2.7.0"
  s.require_paths = ["lib"]
  s.files         = [
    "lib/http_serve.rb",
  ]

  s.add_runtime_dependency("passenger", ["~> 6.0"])
  s.add_development_dependency("dotenv", ["~> 3.1"])
end

# Local Variables:
# mode: ruby
# End:
