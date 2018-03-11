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
          kind: Deployment
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

      context 'with canary == true' do
        let(:modifier) { ResourceModifier.new(resource, tag, true) }

        it 'makes canary changes' do
          modified = modifier.modified_resource
          image =
            modified['spec']['template']['spec']['containers'].first['image']
          name = modified['metadata']['name']
          labels = modified['spec']['template']['metadata']['labels']
          replicas = modified['spec']['replicas']
          env = modified['spec']['template']['spec']['containers'].first['env']

          expect(image).to eq "gapfish/deployer:#{tag}"
          expect(name).to eq 'deployer-canary'
          expect(labels['app']).to eq 'deployer'
          expect(labels['track']).to eq 'canary'
          expect(env).to include('name' => 'TRACK', 'value' => 'canary')
          expect(replicas).to eq 1
        end
      end
    end
  end
end

RSpec.describe DockerImageParser do
  {
    'schasse/echo-host' =>
    { image: 'schasse/echo-host' },

    'schasse/echo-host:mytag' =>
    { image: 'schasse/echo-host', tag: 'mytag' },

    'schasse/echo-host:87678789' =>
    { image: 'schasse/echo-host', tag: '87678789' },

    'gapfish/deployer:v1.0.1' =>
    { image: 'gapfish/deployer', tag: 'v1.0.1' },

    'registry.me.com/gapfish/deployer:v1.0.1' =>
    { image: 'registry.me.com/gapfish/deployer', tag: 'v1.0.1' },

    'registry.me.com:80/gapfish/deployer:v1.0.1' =>
    { image: 'registry.me.com:80/gapfish/deployer', tag: 'v1.0.1' },

    'registry.me.com:80/gapfish/deployer' =>
    { image: 'registry.me.com:80/gapfish/deployer' }
  }.each do |image, parse_result|
    it 'returns the expected' do
      expect(DockerImageParser.parse(image)).to eq parse_result
    end
  end
end
