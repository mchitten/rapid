# encoding: utf-8
module API
  # The +API::Base+ class inherits from ActionController::Metal to offer
  # only the functionality that the API requires.  Using
  # +ActionController::Metal+ means that many standard rails methods
  # may be unavailable in the API.
  #
  # Inherit from +API::Base+ to include API functionality.
  #
  # @example
  #  class Api::V1::InventionsController < API::Base
  #    # Intentionally left blank
  #  end
  class Base < ActionController::Metal
    # Core Rails functionality.
    include AbstractController::Rendering
    include AbstractController::Callbacks
    include ActionController::Rendering
    include ActionController::Renderers::All
    include ActionController::Helpers
    include ActionController::Rescue
    include ActionController::Caching
    if defined?(ActionController::StrongParameters)
      include ActionController::StrongParameters
    end
    include ActionController::Head
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include ActionController::HttpAuthentication::Token::ControllerMethods
    include ActionController::ConditionalGet
    include ActionController::Instrumentation

    # API functionality.
    include API::Rescue
    include API::Response
    include API::Global

    # Ignore verify_authenticity_token -- we don't need it for the API.
    skip_before_filter :verify_authenticity_token

    def self.inherited(base)
      base.send :include, ::Rails.application.routes.url_helpers

      begin
        # Include the base ApplicationHelper, if possible, in the API controller.
        base.send(:include, ::ApplicationHelper)
      rescue NameError
        # No ApplicationHelper.  No problem.
      end
    end
  end
end
