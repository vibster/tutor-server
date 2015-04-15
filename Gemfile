# Copyright 2011-2014 Rice University. Licensed under the Affero General Public
# License version 3 or later.  See the COPYRIGHT file for details.

source 'https://rubygems.org'

# Rails framework
gem 'rails', '4.2.0'

# Bootstrap front-end framework
gem 'bootstrap-sass', '~> 3.2.0'

# SCSS stylesheets
gem 'sass-rails', '~> 5.0.0'

# Compass stylesheets
gem 'compass-rails'

# Automatically add browser-specific CSS prefixes
gem 'autoprefixer-rails'

# JavaScript asset compressor
gem 'uglifier', '>= 1.3.0'

# CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '~> 4.0.0'

# JavaScript asset compiler
gem 'therubyracer', platforms: :ruby

# jQuery library
gem 'jquery-rails'

# Automatically ajaxify links
gem 'turbolinks'

# Rails 5 HTML sanitizer
gem 'rails-html-sanitizer', '~> 1.0'

# Utilities for OpenStax websites
gem 'openstax_utilities', '~> 4.2.0'

# Cron job scheduling
gem 'whenever'

# OpenStax Accounts integration
gem 'openstax_accounts', '~> 5.1'
# OpenStax Exchange integration
gem 'openstax_exchange'

# Datetime parsing
gem 'chronic'

# API versioning and documentation
gem 'openstax_api', '~> 5.3.0'
gem 'apipie-rails'
gem 'maruku'

# Lev framework
gem 'lev', git: 'https://github.com/lml/lev.git', ref: '264819012e'

# Ruby dsl for SQL queries
gem 'squeel'

# Contract management
gem 'fine_print', '~> 3.0.0'

# Keyword search
gem "keyword_search"

# File uploads
gem 'remotipart'
gem 'carrierwave'

# Image editing
gem 'mini_magick'

# Object cloning
gem 'deep_cloneable'

# Real time application monitoring
gem 'newrelic_rpm'

# YAML database backups
gem 'yaml_db'

# Date validations
gem 'validates_timeliness'

# JSON schema validation
gem 'json-schema'

# Cooler hashes
gem 'hashie'

# For calling JSON APIs
gem 'httparty'

# Ordered models
gem 'sortability'

# PostgreSQL database
gem 'pg'

group :development, :test do
  # Get env variables from .env file
  gem 'dotenv-rails'

  # Allows 'ap' alternative to 'pp'
  gem 'awesome_print'

  # Thin development server
  gem 'thin'

  # Call 'binding.pry' anywhere in the code to stop execution and get a debugger console
  gem 'pry' # needed when debugging without 'rails_helper'
  gem 'pry-nav'
  gem 'pry-rails'
  gem 'pry-stack_explorer'

  # Access an IRB console on exceptions page and /console in development
  gem 'web-console', '~> 2.0.0'

  # Mute asset pipeline log messages
  gem 'quiet_assets'

  # Use RSpec for tests
  gem 'rspec-rails'

  gem 'rspec-collection_matchers'

  # Fixture replacement
  gem 'factory_girl_rails'

  # Lorem Ipsum
  gem 'faker'

  # Stubs HTTP requests
  gem 'webmock'

  # Records HTTP requests
  gem 'vcr'

  # Automated security checks
  gem 'brakeman'

  # Time travel gem
  gem 'timecop'

  # Command line reference
  gem 'cheat'

  # Assorted generators
  gem 'nifty-generators'

  # Class diagrams
  gem 'rails-erd'
  gem 'railroady'

  # CoffeeScript source maps
  gem 'coffee-rails-source-maps'

  # Code Climate integration
  gem "codeclimate-test-reporter", require: false

  # Coveralls integration
  gem 'coveralls', require: false
end

group :test do
  gem 'shoulda-matchers', require: false
  gem 'capybara-webkit'
  gem 'launchy'
end

group :production do
  # Unicorn production server
  gem 'unicorn'

  # Unicorn worker killer
  gem 'unicorn-worker-killer'

  # AWS SES
  gem 'aws-ses', '~> 0.6.0', :require => 'aws/ses'

  # Notify developers of Exceptions in production
  gem 'exception_notification'

  # Lograge for consistent logging
  gem 'lograge'
end
