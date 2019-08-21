# frozen_string_literal: true

require 'docker_registry2'

QRegistry =
  if ENV['RACK_ENV'] == 'test'
    # DockerRegistry2.connect('https://quay.io')
    # this will ping the registry, but with quay.io you must provide creds.
    DockerRegistry2.connect('https://registry.hub.docker.com')
  else
    user, password = ENV['DEPLOYER_QUAY_REGISTRY_CREDS']&.split ':'
    DockerRegistry2.connect('https://quay.io', user: user, password: password)
  end
