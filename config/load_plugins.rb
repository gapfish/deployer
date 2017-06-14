# frozen_string_literal: true

begin
  require_relative '../plugins'
rescue LoadError => error
  unless error.message.start_with?('cannot load such file') &&
         error.message.end_with?('plugins')
    raise error
  end
end
