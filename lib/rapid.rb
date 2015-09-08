# encoding: utf-8

# Exception for associations that are not valid.
InvalidAssociation = Class.new(StandardError)

# Dependencies
require 'active_model_serializers'

# QuirkyAPI methods that are available to the entire app.
require 'rapid/global_methods'
include Rapid::Global

require 'rapid/railtie'

module Rapid
  # Core modules
  require 'rapid/configurable'
  require 'rapid/rescue'
  require 'rapid/bouncer'
  require 'rapid/auth'
  require 'rapid/response'
  require 'rapid/can'
  require 'rapid/controller'

  # Serializers
  require 'rapid/serializers/rapid_serializer'
  require 'rapid/serializers/rapid_array_serializer'
end
