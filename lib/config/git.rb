# frozen_string_literal: true

unless defined? Git
  raise "Application initialization failed.\n"\
        'The required singleton git is not available.'
end
