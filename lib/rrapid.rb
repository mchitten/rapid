# encoding: utf-8

# Exception for associations that are not valid.
InvalidAssociation = Class.new(StandardError)

# API helper methods that are available to the entire app.
require 'rrapid/global_methods'
include API::Global

require 'rrapid/railtie'

module API
  # Core modules
  require 'rrapid/configurable'
  require 'rrapid/rescue'
  require 'rrapid/bouncer'
  require 'rrapid/auth'
  require 'rrapid/response'
  require 'rrapid/can'
  require 'rrapid/controller'

  # Serializers
  require 'rrapid/serializers/rrapid_serializer'
  require 'rrapid/serializers/rrapid_array_serializer'

  # Patch to set up Model#active_model_serializer
  require 'active_model/patch'
end
