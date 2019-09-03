# frozen_string_literal: true

require 'deployer'
require 'config/configured_sinatra'
require 'tags'
require 'shared/version'

# rubocop:disable Metrics/BlockLength, Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
# rubocop:disable Metrics/PerceivedComplexity
class DeployServerCreator
  # @return a sinatra server [Class]
  def self.create(auth_token: nil, repositories: [])
    Class.new(ConfiguredSinatra) do
      unless auth_token.nil?
        use Rack::Auth::Basic, 'Restricted Area' do |username, password|
          username == 'auth_token' && password == auth_token
        end
      end

      not_found do
        return 404, { message: 'not found.' }.to_json
      end

      get '/' do
        return 200, { repositories: repositories.map(&:name) }.to_json
      end

      get '/version' do
        return 200, { version: Version.as_string }.to_json
      end

      get '/:repository_name' do
        repository = repositories.find do |repo_candidate|
          repo_candidate.name == params['repository_name']
        end

        return not_found if repository.nil?

        return 200, { repository: repository }.to_json
      end

      post '/:repository_name/deploy' do
        request_id = request.hash
        EventLog.log request_id, 'start'
        EventLog.log request_id, 'deploy'
        repository = repositories.find do |repo_candidate|
          repo_candidate.name == params['repository_name']
        end
        EventLog.log request_id, ['repository', repository&.github]

        return not_found if repository.nil?

        deployer = Deployer.new(
          repository,
          tag: params['tag'], commit: params['commit'], request_id: request_id
        )

        begin
          info = deployer.deploy_info
          EventLog.log request_id, 'success'
          EventLog.flush request_id
          return 200, { message: info }.to_json
        rescue IOError => error
          # TODO: eventlog executor
          EventLog.log(
            request_id, ['user_agent', request.env['HTTP_USER_AGENT'].to_s]
          )
          EventLog.log request_id, error
          EventLog.log request_id, 'fail'
          EventLog.flush request_id
          return 400, { error: error.message }.to_json
        end
      end

      post '/:repository_name/deploy_canary' do
        repository = repositories.find do |repo_candidate|
          repo_candidate.name == params['repository_name']
        end

        return not_found if repository.nil?

        deployer = Deployer.new(
          repository, tag: params['tag'], commit: params['commit'], canary: true
        )

        begin
          info = deployer.deploy_info
          return 200, { message: info }.to_json
        rescue IOError => error
          EventLog.log(
            request_id, ['user_agent', request.env['HTTP_USER_AGENT'].to_s]
          )
          EventLog.log request_id, error
          EventLog.flush request_id
          return 400, { error: error.message }.to_json
        end
      end

      get '/:repository_name/tags' do
        repository = repositories.find do |repo_candidate|
          repo_candidate.name == params['repository_name']
        end

        return not_found if repository.nil?

        tags = RepoTags.new(repository, 'master')
        return 200, { count: tags.count, names: tags.names }.to_json
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength, Metrics/AbcSize
# rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength
# rubocop:enable Metrics/PerceivedComplexity
