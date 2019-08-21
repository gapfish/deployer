# frozen_string_literal: true

unless defined? QRegistry
  raise "Application initialization failed.\n"\
        'The required singleton QRegistry is not available.'
end
