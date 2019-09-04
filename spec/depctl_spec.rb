# frozen_string_literal: true

depctl_file =
  File.expand_path(File.join(File.dirname(__FILE__), '../depctl/bin/depctl.rb'))
load depctl_file
require 'webmock/rspec'
WebMock.allow_net_connect!

RSpec.describe 'depctl' do
  before do
    WebMock.disable_net_connect!
    allow(Api).to receive(:parsed_endpoint).and_return 'https://deployer.de'
    allow(Api).to receive(:token).and_return 'secret_t0ken'
  end

  after { WebMock.allow_net_connect! }

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
      stub =
        stub_request(
          :post,
          "https://deployer.de/deployer/deploy?commit=#{commit}"
        ).with(
          headers:
            { 'Authorization' => 'Basic YXV0aF90b2tlbjpzZWNyZXRfdDBrZW4=' }
        )
      depctl [
        'deploy',
        'deployer',
        '--commit', '6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
      ]
      expect(stub).to have_been_made.once
    end

    it 'works for resource and tag' do
      tag = 'master-6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
      stub = stub_request(
        :post, "https://deployer.de/deployer/deploy?tag=#{tag}")
      depctl [
        'deploy',
        'deployer',
        '--tag', 'master-6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
      ]
      expect(stub).to have_been_made.once
    end

    context 'api returning an error' do
      it 'does not render api response and does not catch error' do
        stub = stub_request(
          :post, "https://deployer.de/deployer/deploy?tag=blabla")
        expect(Api).to receive(:render) { raise IOError }
        expect(Help).to_not receive :render_deploy_help
        expect { depctl %w(deploy deployer --tag=blabla) }.to raise_error
        expect(stub).to have_been_made.once
      end
    end

    context 'current directory is deployer' do
      before do
        allow(Dir).to receive(:pwd).and_return '/home/user/code/deployer'
      end

      it 'works with commit only' do
        commit = '6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
        stub = stub_request(
          :post, "https://deployer.de/deployer/deploy?commit=#{commit}")
        depctl [
          'deploy',
          '--commit', '6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
        ]
        expect(stub).to have_been_made.once
      end

      it 'works with tag only' do
        tag = 'master-6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
        stub = stub_request(
          :post, "https://deployer.de/deployer/deploy?tag=#{tag}")
        depctl [
          'deploy',
          '--tag', 'master-6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
        ]
        expect(stub).to have_been_made.once
      end

      context 'with checked out commit' do
        let(:commit) { '6852531382ae863d82a8fd65bc30dc5a0ff8aa99' }

        before do
          allow(Env).to receive(:current_commit).and_return commit
        end

        it 'work with calculated commit' do
          stub = stub_request(
            :post, "https://deployer.de/deployer/deploy?commit=#{commit}")
          depctl ['deploy']
          expect(stub).to have_been_made.once
        end
      end
    end
  end

  describe 'canary' do
    it 'works with resource and commit' do
      commit = '6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
      stub = stub_request(
        :post, "https://deployer.de/deployer/deploy_canary?commit=#{commit}")
      depctl [
        'canary',
        'deployer',
        '--commit', '6852531382ae863d82a8fd65bc30dc5a0ff8aa99'
      ]
      expect(stub).to have_been_made.once
    end
  end

  describe 'version' do
    it 'sends a request to deployer for the version and asks the Env' do
      expect(Env).to receive(:depctl_version).twice # also in the request header
      stub =
        stub_request(:get, 'https://deployer.de/version').
          to_return(body: { version: '1'}.to_json)
      depctl ['version']
      expect(stub).to have_been_made.once
    end
  end

  describe Api do
    describe '#token' do
      let(:env_file_path) { 'tmp/deployer_env' }
      let(:token) { 'Hier0Kixuuphiv2yexae7ifai8pei7' }

      before do
        allow(Api).to receive(:token).and_call_original
        File.write env_file_path, <<~ENVCONTENT
          export DEPLOYER_AUTH_TOKEN="#{token}"
        ENVCONTENT
        allow(Api).to receive(:env_file).and_return env_file_path
      end

      it 'recognizes tokens from env file' do
        expect(Api.send(:token)).to eq token
      end
    end

    describe '#request' do
      let(:endpoint) { 'http://deployer.my-domain.com' }
      before { allow(Api).to receive(:parsed_endpoint).and_return endpoint }

      it 'prints warning if not using https' do
        expect(Help).to receive(:render_http_warning)
        Api.send :endpoint
      end
    end
  end
end
