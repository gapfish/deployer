# frozen_string_literal: true

depctl_file =
  File.expand_path(File.join(File.dirname(__FILE__), '../depctl/bin/depctl.rb'))
load depctl_file

RSpec.describe 'depctl' do
  before do
    allow(Api).to receive :get
    allow(Api).to receive :post
    allow(Api).to receive :render
  end

  [
    [],
    ['help'],
    ['-h'],
    ['--help'],
    ['--no-option'],
    ['doesntexist']
  ].each do |args|
    it "prints the general help for '#{args.join(' ')}'" do
      expect(Api).not_to receive(:get)
      expect(Help).to receive(:render_general_help)
      depctl args
    end
  end

  describe 'deploy' do
    [
      ['deploy', '-h'],
      ['deploy', '--help'],
      ['deploy', '--no-option', 'mytag'],
      ['deploy', '--tag']
    ].each do |args|
      it "prints the deploy help for '#{args.join(' ')}'" do
        expect(Api).not_to receive(:get)
        expect(Help).to receive(:render_deploy_help)
        depctl args
      end
    end

    it 'works with resource and commit' do
      commit = '6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
      expect(Api).to receive(:post).with "/deployer/deploy?commit=#{commit}"
      depctl [
        'deploy',
        'deployer',
        '--commit', '6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
      ]
    end

    it 'works for resource and tag' do
      tag = 'master-6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
      expect(Api).to receive(:post).with("/deployer/deploy?tag=#{tag}")
      depctl [
        'deploy',
        'deployer',
        '--tag', 'master-6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
      ]
    end

    context 'api returning an error' do
      it 'does not render api response and does not catch error' do
        expect(Api).to receive(:render) { raise IOError }
        expect(Help).to_not receive :render_deploy_help
        expect { depctl %w(deploy deployer --tag=blabla) }.to raise_error
      end
    end

    context 'current directory is deployer' do
      before do
        allow(Dir).to receive(:pwd).and_return '/home/user/code/deployer'
      end

      it 'works with commit only' do
        commit = '6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
        expect(Api).to receive(:post).with("/deployer/deploy?commit=#{commit}")
        depctl [
          'deploy',
          '--commit', '6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
        ]
      end

      it 'works with tag only' do
        tag = 'master-6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
        expect(Api).to receive(:post).with("/deployer/deploy?tag=#{tag}")
        depctl [
          'deploy',
          '--tag', 'master-6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
        ]
      end

      context 'with checked out commit' do
        let(:commit) { '6852531382ae863d82a8fd65bc30dc5a0ff8aa99' }

        before do
          allow(Env).to receive(:current_commit).and_return commit
        end

        it 'work with calculated commit' do
          expect(Api).
            to receive(:post).with("/deployer/deploy?commit=#{commit}")
          depctl ['deploy']
        end
      end
    end
  end

  describe 'canary' do
    it 'works with resource and commit' do
      commit = '6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
      expect(Api).
        to receive(:post).with "/deployer/deploy_canary?commit=#{commit}"
      depctl [
        'canary',
        'deployer',
        '--commit', '6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
      ]
    end
  end

  describe Api do
    describe '#request' do
      let(:endpoint) { 'http://deployer.my-domain.com' }
      before { allow(Api).to receive(:endpoint).and_return endpoint }

      it 'prints warning if not using https' do
        expect(Help).to receive(:render_http_warning)
        expect(Api.send(:https?)).to eq false
      end
    end
  end
end
