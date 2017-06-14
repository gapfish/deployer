# frozen_string_literal: true

unless defined? Log
  raise "Application initialization failed.\n"\
        'The required singleton Log is not available.'
end
