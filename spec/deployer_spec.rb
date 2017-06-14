# frozen_string_literal: true

require 'spec_helper'
require 'deployer'

RSpec.describe Deployer do
  describe '#create' do
    let(:deployer) do
      Deployer.new(
        Config.repositories.find do |repo|
          repo.name == 'sidekiq-monitoring'
        end,
        tag: 'k8s-80f5aedde86d7e83f7dbcec3003f9dff84cfa67f'
      )
    end

    before do
      allow(KubeCtl).to receive :apply
      allow(KubeCtl).to receive :delete
    end

    it 'returns a message, when deploy was successfull' do
      expect(KubeCtl).to receive(:apply).twice do |resource|
        if resource.include? 'Deployment'
          expect(resource).
            to include 'image:\ gapfish/sidekiq-monitoring:'\
                       'k8s-80f5aedde86d7e83f7dbcec3003f9dff84cfa67f'
        end
      end
      expect(KubeCtl).to receive(:delete).once do |resource|
        expect(resource).to include 'sidekiq-monitoring-canary'
      end
      expect(deployer.deploy_info).
        to eq 'sidekiq-monitoring '\
              'k8s-80f5aedde86d7e83f7dbcec3003f9dff84cfa67f is deployed'
    end

    it 'returns false, when deploy was not successfull' do
      error_text = 'could not configure deployment "sidekiq-monitoring"'
      allow(KubeCtl).to receive(:apply) do
        raise IOError, error_text
      end
      # two errors because there are two kube resources
      expect { deployer.deploy_info }.
        to raise_error IOError, [error_text, error_text].join("\n")
    end

    context 'with tag and commit' do
      let(:commit) { '80f5aedde86d7e83f7dbcec3003f9dff84cfa67f' }
      let(:tag) { 'branch-6baf03b900a5007935c737b9c3811a82fbd5e437' }
      let(:deployer) do
        Deployer.new(
          Config.repositories.find do |repo|
            repo.name == 'sidekiq-monitoring'
          end,
          commit: commit,
          tag: tag
        )
      end

      it 'returns successfully deployed' do
        expect(deployer.send(:commit_to_deploy)).to eq commit
        expect(deployer.send(:tag_to_deploy)).to eq tag
        expect(deployer.deploy_info).
          to eq "sidekiq-monitoring #{tag} is deployed"
      end
    end

    context 'with a invalid tag' do
      let(:deployer) do
        Deployer.new(
          Config.repositories.find do |repo|
            repo.name == 'sidekiq-monitoring'
          end,
          tag: 'blabla'
        )
      end

      it 'does not deploy invalid tags' do
        expect(KubeCtl).to_not receive(:apply)
        expect { deployer.deploy_info }.
          to raise_error IOError, 'cannot determine the tag for '\
                                  'repo sidekiq-monitoring'
      end
    end

    context 'with a invalid commit' do
      let(:deployer) do
        Deployer.new(
          Config.repositories.find do |repo|
            repo.name == 'sidekiq-monitoring'
          end,
          commit: 'blabla'
        )
      end

      it 'does not deploy invalid commits' do
        expect(KubeCtl).to_not receive(:apply)
        expect { deployer.deploy_info }.
          to raise_error IOError, 'cannot determine the tag for '\
                                  'repo sidekiq-monitoring and commit blabla'
      end
    end

    context 'with canary releasing style' do
      let(:deployer) do
        Deployer.new(
          Config.repositories.find do |repo|
            repo.name == 'sidekiq-monitoring'
          end,
          tag: 'k8s-80f5aedde86d7e83f7dbcec3003f9dff84cfa67f',
          canary: true
        )
      end

      it 'only applies the deployment to the canary' do
        expect(KubeCtl).to receive(:apply).once
        expect(KubeCtl).to_not receive(:delete)
        deployer.deploy_info
      end
    end
  end
end
