# encoding: utf-8

module API
  # The Session module provides authentication methods to the API.
  module Auth
    def self.included(base)
      base.send(:include, Rapid.auth_system) if Rapid.has_auth_system?
    end
  end
end
