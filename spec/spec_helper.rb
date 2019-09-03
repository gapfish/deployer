# frozen_string_literal: true

ENV['RACK_ENV'] ||= 'test'

require_relative '../config/all'
require 'pry'
require 'webmock/rspec'
WebMock.allow_net_connect!
