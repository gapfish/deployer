# frozen_string_literal: true

require 'spec_helper'
require 'quay_registry'

RSpec.describe QuayRegistry do
  let(:registry) { QuayRegistry.new 'some_token' }
  before { WebMock.disable_net_connect! }
  after { WebMock.disable_net_connect! }

  describe '#tags' do
    context 'with pagination' do
      before do
        tags_page_0 =
          {
            tags: [
              { name: 'a' },
              { name: 'b' }
            ]
          }
        stub_request(
          :get, "https://quay.io/api/v1/repository/org/my_image/tag/?page=0"
        ).to_return(status: 200, body: tags_page_0.to_json)
        tags_page_1 =
          {
            tags: [
              { name: 'c' },
            ]
          }
        stub_request(
          :get, "https://quay.io/api/v1/repository/org/my_image/tag/?page=1"
        ).to_return(status: 200, body: tags_page_1.to_json)
        tags_page_2 =
          {
            tags: []
          }
        stub_request(
          :get, "https://quay.io/api/v1/repository/org/my_image/tag/?page=2"
        ).to_return(status: 200, body: tags_page_2.to_json)
      end

      it 'returns the all tags nicely :)' do
        expect(registry.tags('org/my_image')).
          to eq 'name' => 'org/my_image', 'tags' => ['a', 'b', 'c']
      end
    end

    context 'when unauthorized' do
      before do
        stub_request(
          :get, "https://quay.io/api/v1/repository/org/my_image/tag/?page=0"
        ).to_return(status: 401, body: 'Unauthorized')
      end

      it 'raises when request is unauthorized' do
        expect { registry.tags('org/my_image') }.
          to raise_error QuayRegistry::Error
      end
    end
  end
end
