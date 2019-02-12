# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'deploy_server_creator'

RSpec.describe DeployServerCreator do
  include Rack::Test::Methods

  let(:app) { DeployServerCreator.create(repositories: Config.repositories) }

  describe 'get /404' do
    it 'returns 404' do
      get '/404'
      expect(last_response.status).to eq 404
    end
  end

  describe 'get /' do
    it 'returns 200' do
      get '/'
      expect(last_response).to be_ok
    end

    context 'with basic auth auth_token' do
      let(:app) { DeployServerCreator.create(auth_token: 'abc') }

      it 'returns 401 not authorized' do
        get '/'
        expect(last_response.status).to eq 401
      end
    end
  end

  describe 'get /version' do
    it 'returns a sane version' do
      get '/version'
      expect(last_response).to be_ok
      version = JSON.parse(last_response.body)['version']
      branch, commit = version.match(/(.*)-([^-]+)\z/).captures
      expect(branch).to_not be_nil
      expect(commit).to match(/\A[0-9a-f]{40}\z/)
    end
  end

  describe 'get /:repository_name' do
    it 'includes the github repository' do
      get '/myapp'
      expect(last_response.body).to include 'me/myapp'
    end

    it "returns 'not found', when the repository doesn't exist" do
      get '/doesnt_exist'
      expect(last_response.status).to eq 404
    end
  end

  describe 'post /:repository_name/deploy' do
    let(:deployer) { double }

    before do
      allow(Deployer).to receive(:new).and_return deployer
      allow(deployer).to receive(:deploy_info).and_return true
    end

    it 'returns 200' do
      post '/myapp/deploy'
      expect(last_response).to be_ok
    end

    it 'deploys a specific commit hash' do
      expect(Deployer).
        to receive(:new).
        with(Config.repositories.first,
             commit: 'some_hash', tag: nil, request_id: instance_of(Integer))
      post 'myapp/deploy?commit=some_hash'
    end
  end

  describe 'get /:repository_name/tags' do
    let(:repo_tags) { double }

    it 'renders the repo tags' do
      allow(RepoTags).to receive(:new).and_return repo_tags
      allow(repo_tags).to receive(:count).and_return 2
      allow(repo_tags).to receive(:names).and_return ['master-1', 'master-2']
      get 'deployer/tags'
      expect(last_response).to be_ok
      expect(last_response.body).
        to eq({ count: 2, names: ['master-1', 'master-2'] }.to_json)
    end
  end
end
