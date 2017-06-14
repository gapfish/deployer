# frozen_string_literal: true

require 'spec_helper'
require 'event_stream_logger'
require 'timecop'

RSpec.describe EventStreamLogger do
  let(:event_stream_logger) { EventStreamLogger.new [LogSubscription] }

  describe '#log and #flush' do
    let(:stream_id) { '123456' }
    let(:start_time) do
      Timecop.freeze do
        event_stream_logger.log(stream_id, 'start')
        Time.now
      end
    end
    let(:end_time) do
      Timecop.freeze do
        event_stream_logger.log(stream_id, 'end')
        Time.now
      end
    end
    let(:events) do
      { start_time => 'start', end_time => 'end' }
    end

    it 'sends the event stream to the subscribers' do
      expect(LogSubscription).to receive(:receive).with events
      event_stream_logger.flush stream_id
    end

    it 'deletes the stream' do
      event_stream_logger.log stream_id, 'event'
      event_stream_logger.flush stream_id
      expect(event_stream_logger.send(:streams)[stream_id]).to be nil
    end
  end
end

class Integer
  def seconds_ago
    Time.at Time.now.to_i - self
  end
end

RSpec.describe LogSubscription do
  describe '.receive' do
    context 'with event stream' do
      let(:event_stream) do
        Timecop.freeze do
          {
            60.seconds_ago => 'start',
            59.seconds_ago => 'deploy',
            58.seconds_ago => %w(repository me/myapp),
            30.seconds_ago =>
              %w(commit f9cbfa31ecdc44209a5da167109ec2c2ca556c3f),
            29.seconds_ago =>
              %w(tag test_f9cbfa31ecdc44209a5da167109ec2c2ca556c3f),
            3.seconds_ago => 'success',
            2.seconds_ago => %w(author schasse),
            1.seconds_ago => ['insertions', 10],
            0.seconds_ago => ['deletions', 5]
          }
        end
      end

      it 'writes a log message' do
        # expect(Log).to receive(
        #   'me/myapp;'\
        #   'f9cbfa31ecdc44209a5da167109ec2c2ca556c3f;'\
        #   'start deploy'
        # )
        expect(Log).to receive(:info).with(
          'me/myapp;'\
          'f9cbfa31ecdc44209a5da167109ec2c2ca556c3f;'\
          'deploy success;57s;schasse;+10;-5'
        )
        LogSubscription.receive event_stream
      end
    end
  end
end
