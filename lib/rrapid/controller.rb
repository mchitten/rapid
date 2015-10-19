# encoding: utf-8

module API
  # The +QuirkyApi::Base+ class inherits from ActionController::Metal to offer
  # only the functionality that the API requires.  Using
  # +ActionController::Metal+ means that many standard rails methods
  # may be unavailable in the API.
  #
  # Extend from +API::Base+ to include API functionality.
  #
  # @example
  #  class Api::V1::InventionsController < API::Base
  #    # Intentionally left blank
  #  end
  class Base < ActionController::Metal
    require 'new_relic/agent/instrumentation/rack' if defined?(::NewRelic)
    require 'will_paginate'

    # Core Rails functionality.
    include AbstractController::Rendering
    include AbstractController::Callbacks
    include ActionController::Rendering
    include ActionController::Renderers::All
    include ActionController::Helpers
    include ActionController::Rescue
    include ActionController::Caching
    include ActionController::StrongParameters if defined?(ActionController::StrongParameters)
    include ActionController::Cookies
    include ActionController::Flash
    include ActionController::Head
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include ActionController::HttpAuthentication::Token::ControllerMethods
    include ActionController::ConditionalGet

    # API functionality.
    include API::Auth
    include API::Rescue
    include API::Bouncer
    include API::Response
    include API::Can
    include API::Global

    def self.inherited(base)
      base.send(:include, ::API.auth_system) if API.has_auth_system?
      base.send(:include, API::Bouncer)

      base.send(:include, ActionController::Instrumentation)

      # Ensure that we always trace controller actions in Rails < 4.0.  Rails 4
      # uses ActionController::Instrumentation to automatically watch
      # every request.
      if defined?(Rails)
        # Include Rails routes helpers.
        base.send(:include, ::Rails.application.routes.url_helpers)

        # Basic New Relic configuration for rails apps.  This is ignored if you
        # don't have the new relic gem, or if it's incompatible (rails > 4 has
        # automatic inclusion in the NewRelic gem).
        if Rails::VERSION::STRING.to_f <= 4.0 && defined?(::NewRelic)
          base.send(:include, ::NewRelic::Agent::Instrumentation::ControllerInstrumentation)
          base.send(:before_filter, lambda { self.class.add_transaction_tracer(params[:action].to_sym) })
        end
      end

      begin
        # Include the base ApplicationHelper, if possible, in the API controller.
        base.send(:include, ::ApplicationHelper)
      rescue NameError
        # No ApplicationHelper.  No problem.
      end
    end
  end
end
