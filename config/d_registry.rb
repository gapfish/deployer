# frozen_string_literal: true

require 'docker_registry2'

DRegistry =
  if ENV['RACK_ENV'] == 'test'
    DockerRegistry2.connect('https://registry.hub.docker.com')
  else
    user, password = ENV['DEPLOYER_DOCKER_REGISTRY_CREDS']&.split ':'
    DockerRegistry2.connect(
      'https://registry.hub.docker.com', user: user, password: password
    )
  end
