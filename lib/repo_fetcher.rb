# frozen_string_literal: true

require 'command'
require 'config/log'

class RepoFetcher
  attr_reader :repo

  def initialize(repo)
    @repo = repo
  end

  def pull
    if File.exist? dir_name
      Log.debug "repo #{repo} exists -> fetching remote"
      Dir.chdir(dir_name) do
        Git.fetch
      end
    else
      Log.debug "cloning repo #{repo}"
      Git.clone_github repo
    end
  end

  def in_repo
    pull
    Dir.chdir dir_name do
      Log.debug "Dir.chdir #{dir_name} start"
      Log.debug Command.run 'pwd'
      yield
      Log.debug "Dir.chdir #{dir_name} end"
    end
    Log.debug Command.run 'pwd'
  end

  private

  def dir_name
    repo.split('/').last
  end
end
