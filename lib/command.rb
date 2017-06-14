# frozen_string_literal: true

require 'config/log'

class Command
  def self.run(command, approve_exitcode: true)
    Log.debug command
    output = `#{command} 2>&1`
    Log.debug output
    raise IOError, output if approve_exitcode && !$CHILD_STATUS.success?
    output
  end
end
