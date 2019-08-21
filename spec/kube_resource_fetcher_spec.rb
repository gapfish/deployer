# frozen_string_literal: true

require 'spec_helper'
require 'kube_resource_fetcher'

RSpec.describe KubeResourceFetcher do
  let(:repo) do
    Config.repositories.find { |repo| repo.name == 'sidekiq-monitoring' }
  end
  let(:commit) { '80f5aedde86d7e83f7dbcec3003f9dff84cfa67f' }
  let(:fetcher) { KubeResourceFetcher.new(repo, commit: commit) }
  let(:kube_deploy) do
    YAML.safe_load <<~DEPLOY
      apiVersion: extensions/v1beta1
      kind: Deployment
      metadata:
        name: sidekiq-monitoring
      spec:
        replicas: 1
        template:
          metadata:
            labels:
              pod: sidekiq-monitoring
          spec:
            containers:
            - name: sidekiq-monitoring
              image: gapfish/sidekiq-monitoring
              ports:
              - containerPort: 9292
              env:
              - name: RACK_ENV
                value: production
              - name: REDIS_SENTINEL_SERVICE
                value: redis-sentinel

              resources:
                requests:
                  cpu: 10m
DEPLOY
  end
  let(:kube_svc) do
    YAML.safe_load <<~DEPLOY
      apiVersion: v1
      kind: Service
      metadata:
        name: sidekiq-monitoring
      spec:
        type: ClusterIP
        selector:
          pod: sidekiq-monitoring
        ports:
          - name: http
            port: 80
            targetPort: 9292
            protocol: TCP
DEPLOY
  end

  describe '#resources' do
    it 'returns the kubernetes resources' do
      expect(fetcher.resources.permutation).to include [kube_deploy, kube_svc]
    end

    context 'with non existing commit' do
      let(:commit) { 'b75a0bf4b920c9546c8fbb5edfd16c0d730e9556' }
      it 'raises an exception with expressive message' do
        expect { fetcher.resources }.
          to raise_error 'Cannot find commit '\
                         'b75a0bf4b920c9546c8fbb5edfd16c0d730e9556 in '\
                         'github repository gapfish/sidekiq-monitoring'
      end
    end
  end

  describe '.images' do
    context 'with the resource Deployment' do
      let(:kube_deploy) do
        YAML.safe_load <<~DEPLOY
          apiVersion: extensions/v1beta1
          kind: Deployment
          metadata:
            name: sidekiq-monitoring
          spec:
            replicas: 1
            template:
              metadata:
                labels:
                  pod: sidekiq-monitoring
              spec:
                containers:
                - name: sidekiq-monitoring
                  image: gapfish/sidekiq-monitoring
                  ports:
                  - containerPort: 9292
                  env:
                  - name: RACK_ENV
                    value: production
                  - name: REDIS_SENTINEL_SERVICE
                    value: redis-sentinel

                  resources:
                    requests:
                      cpu: 10m
    DEPLOY
      end
      it 'fetches the image with specified version' do
        kube_deploy['spec']['template']['spec']['containers'][0]['image'] =
          'gapfish/sidekiq-monitoring:v1'
        image = KubeResourceFetcher.images [kube_deploy]
        expect(image).to eq ['gapfish/sidekiq-monitoring:v1']
      end
    end

    context 'with the resource CronJob' do
      let(:cronjob) do
        YAML.safe_load <<~DEPLOY
          apiVersion: batch/v1beta1
          kind: CronJob
          metadata:
            name: calc-liabilities
          labels:
            app: user-and-support
            env: staging
          namespace: default
          spec:
            schedule: "0 6 * * *"
            jobTemplate:
              spec:
                template:
                  spec:
                    containers:
                    - name: calc-liabilities
                      image: gapfish/user-and-support
                      imagePullPolicy: Always
                      command: ["script/user_and_support/calc_liabilities.sh"]
                      env:
                      - name: RAILS_ENV
                        value: staging
                      volumeMounts:
                        - name: secret
                          mountPath: /user-and-support/config/secret.yml
                          subPath: secret.yml
                    volumes:
                      - name: secret
                        secret:
                          secretName: user-and-support-secret
                    restartPolicy: OnFailure
    DEPLOY
      end
      it 'fetches the image with specified version' do
        cronjob.dig(
          'spec', 'jobTemplate', 'spec', 'template',
          'spec', 'containers'
        )[0]['image'] = 'gapfish/sidekiq-monitoring:v1'
        image = KubeResourceFetcher.images [cronjob]
        expect(image).to eq ['gapfish/sidekiq-monitoring:v1']
      end
    end

    context 'with a not modifiable resource' do
      let(:cluster_role) do
        YAML.safe_load <<~DEPLOY
          apiVersion: extensions/v1beta1
          kind: ClusterRole
          metadata:
            name: sidekiq-monitoring
          spec:
            replicas: 1
            template:
              metadata:
                labels:
                  pod: sidekiq-monitoring
              spec:
                containers:
                - name: sidekiq-monitoring
                  image: gapfish/sidekiq-monitoring
                  ports:
                  - containerPort: 9292
                  env:
                  - name: RACK_ENV
                    value: production
                  - name: REDIS_SENTINEL_SERVICE
                    value: redis-sentinel

                  resources:
                    requests:
                      cpu: 10m
    DEPLOY
      end
      it 'returns empty' do
        images = KubeResourceFetcher.images [cluster_role]
        expect(images.empty?).to be_truthy
      end
    end

    context 'with an image from quay.io' do
      let(:kube_deploy) do
        YAML.safe_load <<~DEPLOY
          apiVersion: extensions/v1beta1
          kind: Deployment
          metadata:
            name: sidekiq-monitoring
          spec:
            replicas: 1
            template:
              metadata:
                labels:
                  pod: sidekiq-monitoring
              spec:
                containers:
                - name: sidekiq-monitoring
                  image: quay.io/gapfish/sidekiq-monitoring
                  ports:
                  - containerPort: 9292
                  env:
                  - name: RACK_ENV
                    value: production
                  - name: REDIS_SENTINEL_SERVICE
                    value: redis-sentinel

                  resources:
                    requests:
                      cpu: 10m
        DEPLOY
      end

      it 'returns also the registry' do
        images = KubeResourceFetcher.images [kube_deploy]
        expect(images).to eq ['quay.io/gapfish/sidekiq-monitoring']
      end
    end
  end
end
