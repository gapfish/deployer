# frozen_string_literal: true

require 'bugsnag'

Bugsnag.configure do |config|
  config.api_key = ENV['BUGSNAG_API_KEY']
  config.notify_release_stages = ['production']
  config.project_root = ConfiguredSinatra.root
  ConfiguredSinatra.use Bugsnag::Rack
end

class BugsnagErrorReceiver
  def initialize(event_stream)
    @event_stream = event_stream
  end

  def self.receive(event_stream)
    new(event_stream).send :receive
  end

  private

  attr_reader :event_stream

  def receive
    Bugsnag.notify error if error && !user_agent.start_with?('depctl')
  end

  def error
    event_stream.values.find do |event|
      event.is_a? Exception
    end
  end

  def user_agent
    event_stream.values.find do |event|
      [event].flatten.first == 'user_agent'
    end&.last
  end
end

EventLog.append_subscriber BugsnagErrorReceiver
