# frozen_string_literal: true

require 'spec_helper'
require 'shared/version'

RSpec.describe Version do
  let(:version) { Version.new }
  let(:commit) { '33313ae70574e2a071d294cf1fa78ef8d8c5615a' }

  describe '#as_string' do
    context 'with single git ref' do
      before do
        allow(version).
          to receive(:branch2commit).and_return 'master' => commit
      end

      it 'prints the correct version' do
        expect(version.as_string).to eq "master-#{commit}"
      end
    end

    context 'with multiple refs' do
      let(:other_commit) { '14d670a83e0530d6e56c1daebf0defd3a77cf2d9' }
      before do
        allow(version).to receive(:branch2commit).
          and_return('master' => commit, 'some_branch' => other_commit)
        allow(version).
          to receive(:head).and_return "ref: refs/heads/some_branch\n"
      end

      it 'prints the correct version' do
        expect(version.as_string).to eq "some_branch-#{other_commit}"
      end
    end
  end
end
