# frozen_string_literal: true

require 'spec_helper'
require 'tags'

def mock_docker_registry
  raw_body =
    '{"name":"gapfish/sidekiq-monitoring","tags":["k8s","latest"]}' + "\n"
  allow(DRegistry).
    to receive(:doget).
    with('/v2/gapfish/sidekiq-monitoring/tags/list').
    and_return double(body: raw_body)
end

RSpec.describe ImageTags do
  let(:tags) { ImageTags.new 'gapfish/sidekiq-monitoring' }
  before { mock_docker_registry }

  describe '#count' do
    it 'lists the first 10 available tags' do
      expect(tags.count).to be_positive
    end
  end
end

RSpec.describe RepoTags do
  before do
    allow(RepoTags).to receive(:sleep)
    mock_docker_registry
  end

  let(:images) { ['gapfish/sidekiq-monitoring'] }

  describe '.names' do
    it 'lists for each tag the available images' do
      expect(RepoTags.names(images)).to include 'k8s'
    end
  end

  describe '.find' do
    context 'when there are no images' do
      let(:images) { [] }
      let(:commit) { '0d2b0d2ec2e50568bdaac5a57ca2d771ccc9957e' }

      it 'returns nil' do
        expect(RepoTags.find(images, commit)).to eq nil
      end
    end

    context 'when there are no matching tags' do
      let(:images) { ['gapfish/sidekiq-monitoring'] }
      let(:commit) { '0d2b0d2ec2e50568bdaac5a57ca2d771ccc9957f' }

      it 'returns nil' do
        expect(RepoTags.find(images, commit)).to eq nil
      end
    end

    context 'with matching tags and an image with specified tag' do
      let(:images) { ['schasse/gem_updater:v1', 'gapfish/sidekiq-monitoring'] }
      let(:commit) { 'latest' }

      it 'returns nil' do
        expect(RepoTags.find(images, commit)).to eq 'latest'
      end
    end
  end
end
