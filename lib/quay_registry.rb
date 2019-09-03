require 'net/http'
require 'shared/hyper_texter'
require 'base64'

class QuayRegistry
  ENDPOINT = 'https://quay.io/api/v1'

  class Error < StandardError; end

  def initialize(token)
    @token = token
  end

  def tags(image_name, count = nil, last = nil, page: 0)
    raise "count and last not implemented" unless count.nil? && last.nil?
    response =
      HyperTexter.response_of(
        :get, ENDPOINT,
        "/repository/#{image_name}/tag/?page=#{page}",
        {},
        auth_header
      )
    raise_unless_success!(response)
    tag_names = response.body['tags'].to_a.map { |tag| tag['name'] }
    if tag_names.size == 0
      tag_names
    else
      tag_names + tags(image_name, page: page + 1)
    end
  end

  def auth_header
    { 'Authorization' => "Bearer #{@token}" }
  end

  def raise_unless_success!(response)
    return if response.code.to_s.start_with? '2'
    raise QuayRegistry::Error,
          "(#{response.code} on #{response.uri})"\
          "\n\n#{response.body}"
  end
end
