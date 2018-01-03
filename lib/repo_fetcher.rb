# frozen_string_literal: true

require 'command'
require 'config/log'

class RepoFetcher
  attr_reader :repo

  def initialize(repo, commit:, request_id: nil)
    @repo = repo
    @commit = commit
    @request_id = request_id
    @working_dir = 'tmp'
  end

  def pull
    in_working_dir do
      if File.exist? dir_name
        Log.debug "repo #{repo.github} exists -> fetching remote"
        Dir.chdir(dir_name) do
          Git.fetch
        end
      else
        Log.debug "cloning repo #{repo.github}"
        Git.clone_github repo.github
      end
    end
  end

  def in_commit
    in_repo do
      Git.change_ref commit do
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

  def commit_hash
    commit_hash = nil
    in_repo do
      commit_hash = Git.current_commit_hash
    end
    commit_hash
  end

  private

  attr_reader :working_dir, :commit, :request_id

  def in_repo
    pull
    in_working_dir do
      Dir.chdir dir_name do
        Log.debug "Dir.chdir #{dir_name} start"
        Log.debug Command.run 'pwd'
        yield
        Log.debug "Dir.chdir #{dir_name} end"
      end
      Log.debug Command.run 'pwd'
    end
  end

  def in_working_dir
    Dir.mkdir working_dir unless Dir.exist? working_dir
    Dir.chdir working_dir do
      yield
    end
  end

  def dir_name
    repo.github.split('/').last
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
end
