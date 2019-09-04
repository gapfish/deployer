class HyperTexter
  class << self
    def response_of(method, endpoint, path, params, additional_headers)
      uri = URI.parse(endpoint + path)
      http = Net::HTTP.new uri.host, uri.port
      http.use_ssl = uri.scheme == 'https'
      params = params.to_json if params.is_a? Hash
      request =
        create_request(method, uri.request_uri, params, additional_headers)
      response = http.request request
      parsed_body = JSON.parse response.body
      response.body = parsed_body
      response
    rescue JSON::ParserError
      response
    end

    private


    def create_request(method, uri, body, additional_headers)
      case method
      when :get
        Net::HTTP::Get.new(uri, headers(additional_headers))
      when :post
        Net::HTTP::Post.new(uri, headers(additional_headers))
      else
        raise 'only post and get is implemented'
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
