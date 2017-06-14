# frozen_string_literal: true

require_relative 'config/all'
require 'deploy_server_creator'

run DeployServerCreator.create(
  auth_token: Config.auth_token,
  repositories: Config.repositories
)
