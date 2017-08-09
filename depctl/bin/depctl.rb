#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'yaml'
require_relative '../lib/trollop'
require_relative '../lib/version'

class Help
  class << self
    def cmd(args)
      case args[0]
      when 'tags'
        render_tags_help
      when 'deploy'
        render_deploy_help
      when 'canary'
        render_canary_help
      when 'bug'
        raise 'no bug, just a test'
      else
        render_general_help
      end
    end

    def render_version
      deployer_version = Env.deployer_version
      puts "depctl #{Env.depctl_version}"
      puts "deployer #{deployer_version}"
      puts "ruby #{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"
    end

    def render_general_help
      print <<~HELP
        depctl COMMAND [OPTIONS...]

        Commands:
          build                ALPHA FEATURE: Builds a repository locally and then
                               pushes to registry.
          canary [REPOSITORY]  Deploy a canary for a repository.
          deploy [REPOSITORY]  Deploy a repository.
          ls                   List available repositories.
          show [REPOSITORY]    Show the repository.
          tags [REPOSITORY]    List tags for a repository.
          ------------------------------------------------------------------------
          help [(tags|deploy|canary)] Prints help for the command.
          version                     Prints the depctl and ruby version.
HELP
    end

    def render_tags_help
      print <<~HELP
        depctl tags [REPOSITORY]

        Examples:
          # List tags of prophet.
          depctl tags prophet

          # List tags of current project (folder must correspondent to repository name).
          depctl tags
HELP
    end

    def render_deploy_help
      print <<~HELP
        depctl deploy [REPOSITORY] [(--commit COMMIT | --tag TAG)]

        Examples:
          # Deploy prophet with commit version.
          depctl deploy prophet --commit a025601337e5dc9a4da284e3248d49e78baf0afe

          # Deploy the current version of the current project (folder must
          # correspondent to repository name and the commit is calculated).
          depctl deploy
HELP
    end

    def render_canary_help
      print <<~HELP
        depctl canary [REPOSITORY] [(--commit COMMIT | --tag TAG)]

        This command is very similar to deploy command. It doesn't update the whole
        repository. Instead it creates an additional canary pod in the specified version
        per kubernetes deployment.

        Examples:
          # Deploy a prophet canary with commit version.
          depctl canary prophet --commit a025601337e5dc9a4da284e3248d49e78baf0afe
HELP
    end

    def render_bug_help(exception)
      print <<~HELP
        This is probably a bug. Please report it
        https://github.com/gapfish/k8s/issues and answer the following:

        1. What's the depctl, ruby and os version? Please check that you
        have the newest depctl version.

        depctl version

        2. What did you do?

        3. What did you expect?

        4. What happened?

        5. Give the stacktrace:
HELP
      raise exception
    end

    def render_config_help
      puts 'expected to find the token and url in file like this:'
      puts "# #{ENV['USER_HOME'] || ENV['HOME']}/.deployer/deployer_env}"
      puts 'DEPLOYER_AUTH_TOKEN="adfasljfdklsaj9833"'
      puts 'DEPLOYER_URL="my-deployer.me.com"'
      puts
    end
  end
end

class Env
  def self.repository
    Dir.pwd.split('/').last
  end

  def self.tag
    "#{branch}-#{current_commit}"
  end

  def self.current_commit
    `git rev-parse HEAD`.strip
  end

  def self.branch
    `git rev-parse --abbrev-ref HEAD`.strip
  end

  def self.depctl_version
    Version.as_string
  end

  def self.deployer_version
    JSON.parse(Api.get('/version').body)['version']
  end
end

class Api
  class << self
    def get(path)
      request :get, path
    end

    def post(path)
      request :post, path
    end

    def render(response)
      puts "#{response.code} #{response.class}" unless response.code == '200'
      parsed_response = JSON.parse(response.body)
      puts YAML.dump parsed_response
    rescue JSON::ParserError
      puts response.body
    ensure
      raise IOError unless response.code == '200'
    end

    private

    def request(method, path)
      uri = URI.parse(endpoint + path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      case method
      when :get
        request = Net::HTTP::Get.new(uri.request_uri, info_headers)
      when :post
        request = Net::HTTP::Post.new(uri.request_uri, info_headers)
      else
        raise 'only post and get is implemented'
      end
      request.basic_auth('auth_token', token)
      puts "#{method.upcase} #{uri}"
      wait_for { http.request(request) }
    end

    def wait_for
      thread = Thread.new do
        begin
          i = 0
          frames = %w(▁ ▃ ▅ ▆ ▇ █ ▇ ▆ ▅ ▃)
          loop do
            frame = frames[i % frames.size]
            print "\rLoading #{frame} ... "
            sleep 0.1
            i += 1
          end
        ensure
          print "\rLoading ▇ ... done\n\n"
        end
      end
      value = yield
      thread.kill
      thread.join
      value
    end

    def endpoint
      File.
        read(env_file).
        scan(/DEPLOYER_URL=\"(.*)\"/).
        first.first
    rescue Errno::ENOENT, NoMethodError # file not found or wrong format
      Help.render_config_help
      raise Interrupt
    end

    def token
      if ENV['DEPLOYER_AUTH_TOKEN']
        ENV['DEPLOYER_AUTH_TOKEN']
      else
        File.
          read(env_file).
          scan(/DEPLOYER_AUTH_TOKEN=\"([\d[a-z][A-Z]]*)\"/).
          first.first
      end
    rescue Errno::ENOENT, NoMethodError # file not found or wrong format
      Help.render_config_help
      raise Interrupt
    end

    def env_file
      if File.exist?('/mnt/deployer_env')
        '/mnt/deployer_env'
      elsif File.exist?("#{ENV['HOME']}/.deployer/deployer_env")
        "#{ENV['HOME']}/.deployer/deployer_env"
      else
        Help.render_config_help
        'nofile'
      end
    end

    def info_headers
      {
        'User-Agent' => "depctl/#{Env.depctl_version}",
        'Executor' => ENV['USER']
      }
    end
  end
end

class Tags
  class << self
    def cmd(args)
      repository = args[0] || Env.repository
      response = Api.get "/#{repository}/tags"
      Api.render response
    end
  end
end

class Deploy
  attr_reader :args, :canary
  def initialize(args, canary: false)
    @args = args
    @canary = canary
  end

  def cmd
    Api.render response
  rescue Trollop::CommandlineError, Trollop::HelpNeeded
    Help.render_deploy_help
  end

  def response
    if canary == true
      Api.post "/#{repository}/deploy_canary?#{query_params}"
    else
      Api.post "/#{repository}/deploy?#{query_params}"
    end
  end

  def repository
    if repository_given?
      args[0]
    else
      puts 'INFO: Considering name of working directory as REPOSITORY.'
      Env.repository
    end
  end

  def repository_given?
    args[0] && !args[0].start_with?('-')
  end

  def query_params
    parsed_params.map { |name, value| "#{name}=#{value}" }.join '&'
  end

  def parsed_params
    parsed = Trollop::Parser.new do
      opt :commit, 'commit to deploy', type: :string
      opt :tag, 'tag to deploy', type: :string
    end.parse args
    if !parsed[:commit_given] && !parsed[:tag_given]
      puts 'INFO: Considering head as COMMIT to deploy.'
      { commit: Env.current_commit }
    else
      { commit: parsed[:commit], tag: parsed[:tag] }.compact
    end
  end
end

class Show
  class << self
    def cmd(args)
      return Help.cmd [] if args.size > 1
      repository = args[0] || Env.repository
      response = Api.get "/#{repository}"
      Api.render response
    end
  end
end

class List
  class << self
    def cmd(args)
      return Help.cmd [] unless args.empty?
      response = Api.get '/'
      Api.render response
    end
  end
end

class Build
  attr_reader :args
  def initialize(args)
    @args = args
  end

  def cmd
    puts 'WARNING: building images is an alpha feature'
    return Help.cmd [] unless args.empty?
    images.each do |image|
      dockerfile = dockerfile image
      path = File.dirname dockerfile
      puts "building image #{image}:#{tag} from #{dockerfile}"
      system 'docker build '\
             "--tag #{image}:#{tag} "\
             "--file #{dockerfile} "\
             "#{path}" || raise(IOError)
      puts "pushing #{image}:#{tag}"
      system "docker push #{image}:#{tag}" || raise(IOError)
    end
  end

  def repository
    @repository ||= Env.repository
  end

  def images
    return @images unless @images.nil?
    fetch_images = lambda do |resource|
      resource['spec']['template']['spec']['containers'].map do |container|
        container.fetch('image').split(':').first
      end
    end
    @images =
      resources.
      keep_if { |resource| resource.fetch('kind') == 'Deployment' }.
      map(&fetch_images).
      flatten
  end

  def dockerfile(image)
    docker_dir_file = "docker/#{image}/Dockerfile"
    return docker_dir_file if File.exist? docker_dir_file
    return 'Dockerfile' if images.size == 1
    raise IOError, "no valid Dockerfile found for #{image}"
  end

  def resources
    Dir['kubernetes/**/*.yml'].map do |file|
      YAML.load_file file
    end
  end

  def tag
    @tag ||= Env.tag
  end
end

# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/MethodLength
def depctl(args)
  cmd = args[0]
  cmd_args = args[1..-1] || []
  case cmd
  when 'ls'
    List.cmd cmd_args
  when 'show'
    Show.cmd cmd_args
  when 'tags'
    Tags.cmd cmd_args
  when 'deploy'
    Deploy.new(cmd_args).cmd
  when 'canary'
    Deploy.new(cmd_args, canary: true).cmd
  when 'build'
    Build.new(cmd_args).cmd
  when 'version'
    Help.render_version
  else
    Help.cmd cmd_args
  end
end
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/MethodLength

if $PROGRAM_NAME == __FILE__
  begin
    Dir.chdir ENV['PWD']
    depctl ARGV
  rescue IOError, Interrupt
    exit 1
  rescue StandardError => exception
    Help.render_bug_help exception
  end
end
