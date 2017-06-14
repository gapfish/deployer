# frozen_string_literal: true

class Version
  def self.as_string
    new.as_string
  end

  def as_string
    "#{branch}-#{commit}"
  end

  private

  def commit
    branch2commit[branch]
  end

  def branch
    @branch ||=
      if branch2commit.size == 1
        branch2commit.keys.first
      else
        head.split('/').last.strip
      end
  end

  def branch2commit
    @branch2commit ||= Dir["#{git_folder}/refs/heads/*"].map do |file|
      branch = File.basename file
      commit = File.read(file).strip
      [branch, commit]
    end.to_h
  end

  def head
    File.read("#{git_folder}/HEAD").strip
  end

  def git_folder
    return @git_folder if @git_folder
    install_dir = File.dirname(__FILE__)
    @git_folder =
      File.expand_path(File.join(install_dir, '../../.git'))
  end
end
