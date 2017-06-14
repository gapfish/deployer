require_relative './config/all'
Dir['lib/*.rb'].
  map { |file| file.split('/').last.sub('.rb', '') }.
  each { |klass| require klass }
