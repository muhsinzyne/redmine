# frozen_string_literal: true

# Patch ActiveSupport LoggerThreadSafeLevel for Ruby >= 2.7
if RUBY_VERSION >= "2.7"
  require 'logger'
  
  # Pre-define the module to avoid the constant error
  module ActiveSupport
    module LoggerThreadSafeLevel
    end
  end
end

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])
