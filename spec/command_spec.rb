# frozen_string_literal: true

require 'spec_helper'
require 'command'

RSpec.describe Command do
  describe '.run' do
    let(:text) { 'emacs.' }
    let(:command) { "echo '#{text}'" }

    it 'logs the command' do
      expect(Log).to receive(:debug).with command
      expect(Log).to receive(:debug).with "#{text}\n"
      Command.run command
    end

    it 'returns the output' do
      expect(Command.run(command)).to eq "#{text}\n"
    end

    context 'when command is successful' do
      it 'returns true for successfull command' do
        expect(Command.run('true')).to be_truthy
      end

      it 'does not raise an error, when approve_exitcode is true' do
        expect { Command.run('true', approve_exitcode: true) }.
          to_not raise_error
      end
    end

    context 'when command fails' do
      it 'does not raise an error' do
        expect { Command.run('wtf', approve_exitcode: false) }.
          to_not raise_error
      end

      it 'raises an error, when approve_exitcode is true' do
        expect { Command.run('wtf', approve_exitcode: true) }.
          to raise_error IOError
      end

      it 'returns the output as error message' do
        begin
          Command.run('wtf', approve_exitcode: true)
          expect("that we don't get here because IOError was raised").
            to be true # this expectation is always false
        rescue IOError => error
          expect(error.message).to eq "sh: 1: wtf: not found\n"
        end
      end
    end
  end
end
