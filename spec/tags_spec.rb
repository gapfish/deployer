# frozen_string_literal: true

require 'spec_helper'
require 'tags'

def mock_registry(klass)
  allow(klass).
    to receive(:tags).
    with('gapfish/sidekiq-monitoring').
    and_return(
      'name' => 'gapfish/sidekiq-monitoring',
      'tags' => %w(k8s latest)
    )
end

RSpec.describe ImageTags do
  let(:tags) { ImageTags.new 'gapfish/sidekiq-monitoring' }
  before { mock_registry DRegistry }

  describe '#count' do
    it 'lists the first 10 available tags' do
      expect(tags.count).to be_positive
    end
  end

  describe '#names' do
    it 'returns the tag names' do
      names = ImageTags.new('gapfish/sidekiq-monitoring').names
      expect(names).to eq %w(k8s latest)
    end

    context 'with quay.io image' do
      before { mock_registry QRegistry }

      it 'returns the tag names from quay.io' do
        names = ImageTags.new('quay.io/gapfish/sidekiq-monitoring').names
        expect(names).to eq %w(k8s latest)
      end
    end
  end
end

RSpec.describe RepoTags do
  before do
    allow(RepoTags).to receive(:sleep)
    mock_registry DRegistry
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
