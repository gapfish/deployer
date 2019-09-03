require 'net/http'

class QuayRegistry
  ENDPOINT = 'https://quay.io/api/v1/repository/gapfish/user-and-support/tag/?page=29'

  def initialize(api_token)
    @api_token
  end

  def tags(image_name, count = nil, last = nil)
    raise "count and last not implemented" if count.present? || last.present?

  end
end

class HyperTexter
  class Error < StandardError; end

  class << self
    def get!(endpoint, path, params, additional_headers)
      response_of! :post, endpoint, path, params, additional_headers
    end

    private

    def response_of!(method, endpoint, path, params, additional_headers)
      uri = URI.parse endpoint
      uri.path = path
      http = Net::HTTP.new uri.host, uri.port
      http.use_ssl = uri.scheme == 'https'
      params = params.to_json if params.is_a? Hash
      request =
        create_request(method, uri.request_uri, params, additional_headers)
      response = http.request request
      raise_when_unsuccessful! response, endpoint, path, params
      response.body = JSON.parse response.body
      response
    end

    def raise_when_unsuccessful!(response, endpoint, path, params)
      return if response.code.start_with? '2'

      raise HyperTexter::Error,
            "(#{response.code} on #{endpoint}#{path}) with #{params}"\
            "\n\n#{response.body}"
    end

    def create_request(method, uri, body, additional_headers)
      case method
      when :get
        Net::HTTP::Get.new(uri, headers(additional_headers))
      end.tap { |request| request.body = body }
    end

    def headers(additional_headers)
      {
        'accept' => 'application/json',
        'content-type' => 'application/json'
      }.merge(additional_headers)
    end
  end
end
