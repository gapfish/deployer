# frozen_string_literal: true

require 'kube_resource_fetcher'
require 'command'
require 'shellwords'
require 'tags'
require 'resource_modifier'

class Deployer
  def initialize(repo, tag: nil, commit: nil, canary: false, request_id: nil)
    @repo = repo
    @tag = tag
    @commit = commit
    @canary = canary
    @request_id = request_id
  end

  def deploy_info
    valid_commit_and_tag_or_raise
    resource_available_or_raise
    if canary == false && errors_during_canary_deletion.any?
      raise IOError, errors_during_canary_deletion.join("\n")
    end
    raise IOError, errors_during_deploy.join("\n") if errors_during_deploy.any?
    "#{repo.name} #{tag_to_deploy} is deployed#{canary_info}"
  end

  private

  def canary_info
    ' as canary' if @canary == true
  end

  def valid_commit_and_tag_or_raise
    raise IOError, 'commit or tag must be given' if tag.nil? && commit.nil?
    if tag_to_deploy.nil? || commit_to_deploy.nil?
      raise IOError, "cannot determine the tag for repo #{repo.name}"
    end
    'commit and tag valid'
  end

  def resource_available_or_raise
    if resource_fetcher.resources.empty?
      raise IOError, 'no resources found for '\
                     "repo #{repo.name} and tag #{tag_to_deploy}"
    end
    'resource available'
  end

  def errors_during_canary_deletion
    return @canary_errors unless @canary_errors.nil?
    @canary_errors = []
    resource_fetcher.deploys.each do |resource|
      canary_true = true
      canary_deploy =
        ResourceModifier.new(resource, tag_to_deploy, canary_true).
        modified_resource
      begin
        KubeCtl.delete YAML.dump(canary_deploy).shellescape
      rescue IOError => error
        @canary_errors << error.message
      end
    end
    @canary_errors
  end

  def errors_during_deploy
    return @error_messages unless @error_messages.nil?
    @error_messages = []
    resources.each do |resource|
      modified_resource =
        ResourceModifier.new(resource, tag_to_deploy, canary).modified_resource
      begin
        KubeCtl.apply YAML.dump(modified_resource).shellescape
      rescue IOError => error
        @error_messages << error.message
      end
    end
    @error_messages
  end

  def resources
    return resource_fetcher.deploys if canary == true
    resource_fetcher.resources
  end

  def resource_fetcher
    @resource_fetcher ||=
      KubeResourceFetcher.new(
        repo, commit: commit_to_deploy, request_id: request_id
      )
  end

  attr_reader :commit, :repo, :tag, :canary, :request_id

  def commit_to_deploy
    return @commit_to_deploy unless @commit_to_deploy.nil?
    _, tag_commit = tag&.scan(/([\w]*)-([\d[a-f]]*)/)&.first
    @commit_to_deploy = commit_hash || tag_commit
    EventLog.log request_id, ['commit', @commit_to_deploy]
    @commit_to_deploy
  end

  def commit_hash
    return commit if commit != 'master'
    RepoFetcher.new(repo, commit: 'master', request_id: request_id).
      commit_hash
  end

  def tag_to_deploy
    return @tag_to_deploy unless @tag_to_deploy.nil?
    @tag_to_deploy = tag || RepoTags.new(repo, commit_to_deploy).find
    EventLog.log request_id, ['tag', @tag_to_deploy]
    @tag_to_deploy
  end
end

class KubeCtl
  class << self
    def apply(resource)
      Command.run "echo #{resource} | kubectl apply -f -"
    end

    def delete(resource)
      Command.run "echo #{resource}"\
                  ' | kubectl delete --ignore-not-found=true -f -'
    end
  end
end
