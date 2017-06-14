# frozen_string_literal: true

require 'logger'

Log =
  if ENV['RACK_ENV'] == 'test'
    if ENV['DEBUG'] || ENV['VERBOSE']
      Logger.new(STDOUT).tap { |logger| logger.level = Logger::DEBUG }
    else
      Logger.new '/dev/null'
    end
  else
    Logger.new(STDOUT).tap do |logger|
      logger.level =
        if ENV['DEBUG'] || ENV['VERBOSE']
          Logger::DEBUG
        else
          Logger::INFO
        end
    end
  end
