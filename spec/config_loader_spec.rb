# frozen_string_literal: true

require 'spec_helper'
require 'config_loader'

RSpec.describe ConfigLoader do
  let(:config_path) { 'tmp/test_config.yml' }
  let(:config_override_path) { 'tmp/override_test_config.yml' }
  let(:env) { {} }
  let(:config) { ConfigLoader.new({}, config_path, config_override_path) }

  context 'with config files' do
    before do
      File.write config_path, <<~CONFIG
        repositories:
          - name: myapp
            github: me/myapp
          - name: legacy_app
            subversion: svn://svn-repositories.com/legacy_app
CONFIG

      File.write config_override_path, <<~CONFIG
        github_token: abc
        auth_token: cba
CONFIG
    end

    after do
      File.delete config_path
      File.delete config_override_path
    end

    describe '.repositories' do
      it 'returns prophet' do
        repo = config.repositories.first
        expect(repo.name).to eq 'myapp'
        expect(repo.github).to eq 'me/myapp'
        expect(repo.kube_resource).to eq 'kubernetes'
      end

      context 'with kube_resource defined' do
        before do
          File.write config_path, <<~CONFIG
            repositories:
              - name: myapp
                github: me/myapp
                kube_resource: other_folder
CONFIG
        end

        it 'recognizes other kube_resource' do
          expect(config.repositories.first.kube_resource).to eq 'other_folder'
        end
      end

      describe '.subversion' do
        it 'returns the subversion url' do
          expect(config.repositories[1].subversion).
            to eq 'svn://svn-repositories.com/legacy_app'
        end
      end
    end

    describe '.github_token' do
      it 'returns a token' do
        expect(config.github_token).to eq 'abc'
      end
    end

    describe '.auth_token' do
      it 'returns a token' do
        expect(config.auth_token).to eq 'cba'
      end
    end

    context 'with additional env variables' do
      let(:env) do
        {
          'DEPLOYER_GITHUB_TOKEN' => 'abc',
          'DEPLOYER_AUTH_TOKEN' => 'cba'
        }
      end

      describe '.github_token' do
        it 'returns a token' do
          expect(config.github_token).to eq 'abc'
        end
      end

      describe '.auth_token' do
        it 'returns a token' do
          expect(config.auth_token).to eq 'cba'
        end
      end
    end

    context 'without secrets from config_overrid_path' do
      let(:config) { ConfigLoader.new({}, config_path) }

      describe '.github_token' do
        it 'returns nil' do
          expect(config.github_token).to be_nil
        end
      end

      describe '.auth_token' do
        it 'returns nil' do
          expect(config.auth_token).to be_nil
        end
      end
    end
  end
end
