# frozen_string_literal: true

class EventStreamLogger
  def initialize(subscribers)
    @subscribers = subscribers
  end

  def log(stream_id, event_name)
    events(stream_id)[Time.now] = event_name
  end

  def flush(stream_id)
    flushed_event_stream = streams.delete stream_id
    subscribers.each do |subscriber|
      subscriber.receive flushed_event_stream
    end
  end

  def append_subscriber(subscriber)
    @subscribers << subscriber
  end

  private

  attr_reader :subscribers

  def events(stream_id)
    streams[stream_id] ||= {}
  end

  # hopefully hashes are thread safe :D
  def streams
    @streams ||= {}
  end
end

class LogSubscription
  def initialize(event_stream)
    @event_stream = event_stream
  end

  def self.receive(event_stream)
    new(event_stream).send :receive
  end

  private

  attr_reader :event_stream

  def receive
    Log.info(
      "#{repository};#{commit};#{kind} #{success_state};#{duration}s;"\
      "#{commit_author};+#{insertions};-#{deletions}"
    )
  end

  def repository
    event_stream.values.find do |event|
      [event].flatten.first == 'repository'
    end&.last
  end

  def commit
    event_stream.values.find do |event|
      [event].flatten.first == 'commit'
    end&.last
  end

  def kind
    event_stream.values.find do |event|
      event == 'deploy'
    end
  end

  def success_state
    event_stream.values.find do |event|
      event == 'success' || event == 'fail'
    end
  end

  def duration
    start_time = event_stream.key 'start'
    end_time = event_stream.key('fail') || event_stream.key('success')
    end_time.to_i - start_time.to_i
  end

  def commit_author
    event_stream.values.find do |event|
      [event].flatten.first == 'author'
    end&.last
  end

  def insertions
    event_stream.values.find do |event|
      [event].flatten.first == 'insertions'
    end&.last
  end

  def deletions
    event_stream.values.find do |event|
      [event].flatten.first == 'deletions'
    end&.last
  end
end
