# frozen_string_literal: true

require 'config/git'
require 'repo_fetcher'
require 'yaml'

class KubeResourceFetcher
  def initialize(repo, commit:, request_id: nil)
    @repo = repo
    @commit = commit
    @request_id = request_id
  end

  def resources
    return @resources unless @resources.nil?
    @resources = []
    in_commit do
      Dir["#{repo.kube_resource}/**/*.yml"].each do |resource_file|
        @resources << YAML.load_file(resource_file)
      end
    end
    @resources
  end

  def images
    self.class.images resources
  end

  def deploys
    resources.select do |resource|
      resource.fetch('kind') == 'Deployment'
    end
  end

  private

  attr_reader :repo, :commit, :request_id

  def in_commit
    RepoFetcher.new(repo, commit: commit, request_id: request_id).in_commit do
      yield
    end
  end

  class << self
    # NOTE: just for testing purposes this is a class method
    def images(resources)
      resources.map do |resource|
        resource_kind = resource.fetch('kind')
        next unless %w(Deployment StatefulSet CronJob).include? resource_kind
        fetch_images(resource_kind, resource)
      end.compact.flatten
    end

    def fetch_images(resource_kind, resource)
      containers = resource.dig('spec', 'template', 'spec', 'containers')
      if resource_kind == 'CronJob'
        containers = resource.dig('spec', 'jobTemplate', 'spec', 'template',
              'spec', 'containers')
      end
      containers.map do |container|
          container.fetch('image')
      end
    end
  end
end
