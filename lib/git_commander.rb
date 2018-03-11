# frozen_string_literal: true

require 'command'

class GitCommander
  def initialize(github_token = nil, git_url = nil)
    @github_token = github_token
    @git_url = git_url
  end

  def change_ref(reference)
    working_reference = current_branch
    raise ArgumentError, 'reference must not be nil' if reference.nil?
    Command.run "#{git} checkout #{reference}"
    yield
  ensure
    Command.run "#{git} checkout #{working_reference}"
  end

  def ref_exists?(branch)
    Command.run "#{git} rev-parse --verify #{branch}", approve_exitcode: true
    true
  rescue IOError
    false
  end

  def current_branch
    Command.run("#{git} rev-parse --abbrev-ref HEAD").strip
  end

  def current_commit_hash
    Command.run("#{git} rev-parse HEAD").sub("\n", '')
  end

  def current_commit_author
    Command.run("#{git} log -n 1 --format=%cn").strip
  end

  def current_commit_stats
    stats = Command.run("#{git} show --stat").strip
    files = stats.scan(/(\d+) file[s]* changed/).first&.first || 0
    insertions = stats.scan(/(\d+) insertion[s]*/).first&.first || 0
    deletions = stats.scan(/(\d+) deletion[s]*/).first&.first || 0
    { files: files, insertions: insertions, deletions: deletions }
  end

  def commit(message)
    Command.run "#{git} add ."
    Command.run "#{git} commit -a -m '#{message}'"
  rescue IOError => error
    raise error unless error.message.include? 'nothing to commit'
  end

  def push
    Command.run "#{git} push origin #{current_branch}"
  end

  def pull
    Command.run "#{git} pull origin #{current_branch}"
  end

  def merge(branch)
    Command.run "GIT_MERGE_AUTOEDIT=no #{git} pull origin #{branch}"
  end

  def pull_request(message)
    Command.run "GITHUB_TOKEN=#{@github_token} hub pull-request -m '#{message}'"
  end

  def checkout(branch, file)
    Command.run "#{git} checkout #{branch} #{file}"
  end

  def clone_github(repo)
    Command.run "#{git} clone https://github.com/#{repo}.git"
  end

  def fetch
    Command.run "#{git} fetch"
  end

  private

  def git
    @git ||=
      'git -c user.email=deployer@deployer.com -c user.name=Deployer' +
      if @github_token
        " -c url.https://#{@github_token}:x-oauth-basic@"\
          'github.com/.insteadof=https://github.com/'
      elsif @git_url
        " -c url.#{@git_url}.insteadof=https://github.com/"
      else
        ''
      end
  end
end
