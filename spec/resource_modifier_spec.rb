# frozen_string_literal: true

require 'spec_helper'
require 'resource_modifier'
require 'yaml'

RSpec.describe ResourceModifier do
  describe '#modified_resource' do
    let(:tag) { 'master-57887667890' }
    let(:canary) { false }
    let(:modifier) { ResourceModifier.new(resource, tag, canary) }

    context 'with specified image tag' do
      let(:resource) do
        YAML.safe_load <<~DEPLOY
          apiVersion: extensions/v1beta1
          kind: Deployment
          metadata:
            name: deployer
          spec:
            replicas: 1
            strategy:
              type: RollingUpdate
            template:
              metadata:
                labels:
                  app: deployer
              spec:
                containers:
                - name: deployer
                  image: gapfish/deployer:v1.0.1
DEPLOY
      end

      it 'leaves the existing image tag' do
        modified = modifier.modified_resource
        image =
          modified['spec']['template']['spec']['containers'].first['image']
        expect(image).to eq 'gapfish/deployer:v1.0.1'
      end
    end

    context 'with unspecified image tag' do
      let(:resource) do
        YAML.safe_load <<~DEPLOY
          apiVersion: extensions/v1beta1
          kind: CronJob
          metadata:
            name: deployer
          spec:
            replicas: 2
            strategy:
              type: RollingUpdate
            template:
              metadata:
                labels:
                  app: deployer
              spec:
                containers:
                - name: deployer
                  image: gapfish/deployer
DEPLOY
      end

      it 'adds correct image tag' do
        modified = modifier.modified_resource
        image =
          modified['spec']['template']['spec']['containers'].first['image']
        expect(image).to eq "gapfish/deployer:#{tag}"
      end

      modifiables = %w(Deployment StatefulSet CronJob)
      modifiables.each do |resource_kind|
        context "with canary == true and resource kind: #{resource_kind}" do
          let(:resource) do
            YAML.safe_load <<~DEPLOY
              apiVersion: extensions/v1beta1
              kind: #{resource_kind}
              metadata:
                name: deployer
              spec:
                replicas: 2
                strategy:
                  type: RollingUpdate
                template:
                  metadata:
                    labels:
                      app: deployer
                  spec:
                    containers:
                    - name: deployer
                      image: gapfish/deployer
    DEPLOY
          end

          let(:modifier) { ResourceModifier.new(resource, tag, true) }

          it 'makes canary changes' do
            modified = modifier.modified_resource
            image =
              modified['spec']['template']['spec']['containers'].first['image']
            name = modified['metadata']['name']
            labels = modified['spec']['template']['metadata']['labels']
            replicas = modified['spec']['replicas']
            env =
              modified['spec']['template']['spec']['containers'].first['env']
            expect(image).to eq "gapfish/deployer:#{tag}"
            expect(name).to eq 'deployer-canary'
            expect(labels['app']).to eq 'deployer'
            expect(labels['track']).to eq 'canary'
            expect(env).to include('name' => 'TRACK', 'value' => 'canary')
            expect(replicas).to eq 1
          end
        end
      end

      context 'with a not modifiable resource' do
        let(:resource) do
          YAML.safe_load <<~DEPLOY
            apiVersion: extensions/v1beta1
            kind: ClusterRole
            metadata:
              name: deployer
            spec:
              replicas: 2
              strategy:
                type: RollingUpdate
              template:
                metadata:
                  labels:
                    app: deployer
                spec:
                  containers:
                  - name: deployer
                    image: gapfish/deployer
  DEPLOY
        end
        let(:modifier) { ResourceModifier.new(resource, tag, true) }

        it 'does not make the changes' do
          modified = modifier.modified_resource
          image =
            modified['spec']['template']['spec']['containers'].first['image']
          expect(image).to eq 'gapfish/deployer'
        end
      end
    end
  end
end
