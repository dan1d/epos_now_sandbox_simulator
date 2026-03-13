# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "epos_now_sandbox_simulator"
  spec.version       = "0.1.0"
  spec.authors       = ["dan1d"]
  spec.email         = ["dan1d@users.noreply.github.com"]

  spec.summary       = "Epos Now POS sandbox data simulator"
  spec.description   = "A Ruby gem for simulating Point of Sale operations against the Epos Now API. " \
                       "Generates realistic orders, payments, and transaction data for testing."
  spec.homepage      = "https://github.com/dan1d/epos_now_sandbox_simulator"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.files = Dir.glob("{bin,lib}/**/*") + %w[LICENSE README.md Gemfile]
  spec.bindir        = "bin"
  spec.executables   = ["simulate"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "activerecord", "~> 8.0"
  spec.add_dependency "concurrent-ruby", "~> 1.2"
  spec.add_dependency "dotenv", "~> 3.0"
  spec.add_dependency "factory_bot", "~> 6.4"
  spec.add_dependency "faker", "~> 3.2"
  spec.add_dependency "pg", "~> 1.5"
  spec.add_dependency "rest-client", "~> 2.1"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "tzinfo", "~> 2.0"
  spec.add_dependency "zeitwerk", "~> 2.6"

  # Development dependencies
  spec.add_development_dependency "database_cleaner-active_record", "~> 2.1"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "rubocop-rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "vcr", "~> 6.1"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.metadata["rubygems_mfa_required"] = "true"
end
