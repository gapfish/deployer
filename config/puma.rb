# frozen_string_literal: true

# the puma config won't be required like the other configs, but will
# be passed to the puma command
quiet false
threads 0, 1
bind 'tcp://0.0.0.0:8080'
