# frozen_string_literal: true

require 'git_commander'
require_relative './config'

Git =
  if ENV['RACK_ENV'] == 'test'
    GitCommander.new
  else
    GitCommander.new(
      Config.github_token, Config.gitlab_domain, Config.gitlab_token, Config.ssh
    )
  end
