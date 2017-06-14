# frozen_string_literal: true

require 'config/git'
require 'repo_fetcher'
require 'yaml'

class KubeResourceFetcher
  def initialize(repo, commit:, request_id: nil)
    @repo = repo
    @commit = commit
    @working_dir = 'tmp'
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

  attr_reader :repo, :working_dir, :commit, :request_id

  def in_commit
    in_repo do
      Git.change_ref commit do
        Git.pull
        log_events
        yield
      end
    end
  rescue IOError => exception
    if exception.message.start_with? 'fatal: reference is not a tree'
      raise IOError, "Cannot find commit #{commit} in "\
                     "github repository #{repo.github}"
    end
    raise exception
  end

  def in_repo
    Dir.mkdir working_dir unless Dir.exist? working_dir
    Dir.chdir working_dir do
      RepoFetcher.new(repo.github).in_repo do
        yield
      end
    end
  end

  def log_events
    return if request_id.nil?
    EventLog.log request_id, ['author', commit_author]
    EventLog.log request_id, ['insertions', commit_insertions]
    EventLog.log request_id, ['deletions', commit_deletions]
  end

  def commit_author
    Git.current_commit_author
  end

  def commit_insertions
    commit_stats[:insertions]
  end

  def commit_deletions
    commit_stats[:deletions]
  end

  def commit_stats
    @commit_stats ||= Git.current_commit_stats
  end

  class << self
    # NOTE: just for testing purposes this is a class method
    def images(resources)
      fetch_images = lambda do |resource|
        resource['spec']['template']['spec']['containers'].map do |container|
          container.fetch('image')
        end
      end
      resources.
        select { |resource| resource.fetch('kind') == 'Deployment' }.
        map(&fetch_images).
        flatten
    end
  end
end
