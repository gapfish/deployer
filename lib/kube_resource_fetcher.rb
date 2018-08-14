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
      fetch_images = lambda do |resource|
        resource['spec']['template']['spec']['containers'].map do |container|
          container.fetch('image')
        end
      end
      modifiable = lambda do |resource|
        %w(Deployment StatefulSet CronJob).include? resource.fetch('kind')
      end
      resources.select(&modifiable).map(&fetch_images).flatten
    end
  end
end
