# frozen_string_literal: true

require 'yaml'

class ConfigLoader
  def initialize(env = {}, config_path = '', config_override_path = '')
    @config_path = config_path
    @config_override_path = config_override_path
    @env = env
  end

  def github_token
    @env['DEPLOYER_GITHUB_TOKEN'] || config['github_token']
  end

  def gitlab_domain
    @env['DEPLOYER_GITLAB_DOMAIN'] || config['gitlab_domain']
  end

  def gitlab_token
    @env['DEPLOYER_GITLAB_TOKEN'] || config['gitlab_token']
  end

  def auth_token
    return @env['DEPLOYER_AUTH_TOKEN'] unless @env['DEPLOYER_AUTH_TOKEN'].nil?
    return config['auth_token'] unless config['auth_token'].nil?
    raise('Protect your service man!') if @env['RACK_ENV'] == 'production'
  end

  def repositories
    return @repositories unless @repositories.nil?
    # TODO: repositories syntax in env
    repo_hashes =
      @env['DEPLOYER_REPOSITORIES'] ||
      config['repositories'] || raise('No repositories defined!')
    @repositories = repo_hashes.map { |repo_hash| RepoConfig.new repo_hash }
  end

  def plugins
    if !@env['DEPLOYER_PLUGINS'].nil?
      @env['DEPLOYER_PLUGINS'].split(',')
    else
      config['plugins'] || []
    end
  end

  private

  def config
    @config ||= loaded_config
  end

  def loaded_config
    load_config(@config_path).
      merge(load_config(@config_override_path))
  end

  def load_config(file)
    if File.exist? file
      YAML.load_file file
    else
      {}
    end
  end
end

class RepoConfig
  attr_reader :name, :github, :kube_resource
  def initialize(repo_hash)
    @name = repo_hash.fetch 'name'
    @github = repo_hash.fetch 'github'
    @kube_resource = repo_hash['kube_resource'] || 'kubernetes'
  end

  def to_h
    { name: name, github: github, kube_resource: kube_resource }
  end

  def to_json(*args)
    to_h.to_json(args)
  end
end
