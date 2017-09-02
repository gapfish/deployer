# frozen_string_literal: true

class Subversion
  class << self
    def checkout(repo_url, dirname)
      Command.run "svn checkout #{repo_url} #{dirname}"
    end

    def update(revision: nil)
      revision_arg = revision && "-r #{revision}"
      Command.run "svn update #{revision_arg}"
    end
  end
end
