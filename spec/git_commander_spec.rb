# frozen_string_literal: true

require 'spec_helper'
require 'git_commander'

RSpec.describe GitCommander do
  let(:git_commander) { GitCommander.new }
  before do
    @git = git_commander.send :git
    `mkdir -p tmp/test_repo`
    Dir.chdir 'tmp/test_repo'
    `#{@git} init .`
    `touch masterfile`
    `#{@git} add masterfile`
    `#{@git} commit -m 'create a master file'`
    `#{@git} branch other_branch`
  end

  after do
    Dir.chdir '../..'
    `rm -rf tmp/test_repo`
  end

  describe '#change_ref' do
    it 'runs the block' do
      block = double
      expect(block).to receive(:run)
      git_commander.change_ref('other_branch') { block.run }
    end

    it 'throws an exception, when it does not exist' do
      expect { git_commander.change_ref('another_branch') {} }.
        to raise_error IOError
    end

    it 'goes back to the current branch' do
      working_dir = `pwd`
      git_commander.change_ref('other_branch') {}
      expect(`pwd`).to eq working_dir
    end
  end

  describe '#ref_exists?' do
    it 'returns true, when the branch exists' do
      expect(git_commander.ref_exists?('master')).to be true
    end

    it 'returns false, when the branch does not exist' do
      expect(git_commander.ref_exists?('doesntexist')).to be false
    end
  end

  describe '#current_branch' do
    it 'returns the name of the current branch' do
      expect(git_commander.current_branch).to eq 'master'
    end
  end

  describe '#current_commit_has' do
    it 'returns a commit hash' do
      expect(git_commander.current_commit_hash).to match(/\A[a-z0-9]{40}\z/)
    end
  end

  describe '#commit' do
    it 'creates a commit with the specified commit message' do
      `touch commit_file`
      git_commander.commit('commitment sucks')
      expect(`#{@git} log`).to include 'commitment sucks'
    end

    it 'does not commit when there is no new file' do
      git_commander.commit('commitment sucks')
      expect(`#{@git} log`).not_to include 'commitment sucks'
    end
  end

  describe '#checkout' do
    it 'checks out a a file on a specific branch' do
      git_commander.change_ref('other_branch') do
        git_commander.checkout 'master', 'masterfile'
        expect(`ls`).to include 'masterfile'
      end
    end
  end

  describe '#current_commit_stats' do
    it 'shows the commit stats' do
      expect(git_commander.current_commit_stats).
        to eq files: '1', insertions: '0', deletions: '0'
    end
  end

  describe '#current_commit_author' do
    it 'shows the commit stats' do
      expect(git_commander.current_commit_author).
        to eq 'Deployer'
    end
  end

  # describe '#clone_github' do
  # it 'clones private repos' do
  # commander  = GitCommander.new('TOKEN')
  # repo = 'gapfish/pass'
  # commander.clone_github(repo)
  # end
  # end
end
