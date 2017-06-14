# frozen_string_literal: true

require 'sinatra'

class ConfiguredSinatra < Sinatra::Base
  set :root, File.expand_path('..', File.dirname(__FILE__))
  set :server, :puma
  if ENV['RACK_ENV'] == 'production'
    set :raise_errors, true
    set :show_exceptions, false
  end
  use Rack::CommonLogger, Log
end
