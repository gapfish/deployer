# frozen_string_literal: true

Config.plugins.each do |plugin|
  require_relative "plugins/#{plugin}"
end
