# frozen_string_literal: true

require 'config_loader'

Config =
  if ENV['RACK_ENV'] == 'test'
    ConfigLoader.new(
      'RACK_ENV' => 'test',
      'DEPLOYER_REPOSITORIES' =>
      [
        { 'name' => 'myapp', 'github' => 'me/myapp' },
        {
          'name' => 'sidekiq-monitoring',
          'github' => 'gapfish/sidekiq-monitoring'
        },
        {
          'name' => 'deployer',
          'github' => 'gapfish/deployer'
        },
        {
          'name' => 'din-tutorial',
          'subversion' => 'svn://localhost/din-tutorial/trunk'
        }
      ]
    )
  else
    ConfigLoader.new(ENV, 'config.yml', 'config.override.yml')
  end
