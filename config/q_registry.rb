# frozen_string_literal: true

require 'quay_registry'

QRegistry =
  if ENV['RACK_ENV'] == 'test'
    QuayRegistry.new 'some_token'
  else
    token = ENV['DEPLOYER_QUAY_API_TOKEN']
    QuayRegistry.new token
  end
