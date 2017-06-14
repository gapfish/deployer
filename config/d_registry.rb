# frozen_string_literal: true

require 'docker_registry2'

DRegistry =
  if ENV['RACK_ENV'] == 'test'
    DockerRegistry.connect('https://registry.hub.docker.com')
  else
    DockerRegistry.connect(
      "https://#{ENV['DEPLOYER_DOCKER_REGISTRY_CREDS']}@"\
      'registry.hub.docker.com'
    )
  end
