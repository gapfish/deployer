# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'rubygems'
require 'bundler'

if ENV['RACK_ENV'] == 'test'
  Bundler.setup :default, :test
else
  Bundler.setup :default
end
