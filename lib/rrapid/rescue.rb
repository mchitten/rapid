# encoding: utf-8

module API
  # The Rescue module rescues certain exceptions and returns their responses
  # in a JSON response.  If +API.show_exceptions+ is specified, all
  # of the rescued exceptions below will not be rescued, and will raise.
  module Rescue
    def self.included(base)
      if base.respond_to?(:rescue_from) && !API.show_exceptions
        base.send :rescue_from, '::StandardError', with: :render_internal_server_error         # 500 Internal Server Error
        base.send :rescue_from, '::InvalidAssociation', with: :render_bad_request              # 400 Bad Request
        base.send :rescue_from, '::ActiveRecord::RecordInvalid', with: :render_record_invalid  # 400 Bad Request
        base.send :rescue_from, '::ActiveRecord::RecordNotFound', with: :render_not_found      # 404 Not Found
        base.send :rescue_from, '::ActiveRecord::RecordNotUnique', with: :render_conflict      # 409 Conflict
      end
    end
  end
end
