# encoding: utf-8

module API
  # The Rescue module rescues certain exceptions and returns their responses
  # in a JSON response.  If +API.show_exceptions+ is specified, all
  # of the rescued exceptions below will not be rescued, and will raise.
  module Rescue
    def self.included(base)
      if base.respond_to?(:rescue_from) && !API.show_exceptions
        base.send :rescue_from, '::StandardError', with: :internal_error                # 500 Internal Server Error
        base.send :rescue_from, '::CanCan::AccessDenied', with: :unauthorized           # 401 Unauthorized
        base.send :rescue_from, '::InvalidAssociation', with: :error                    # 400 Bad Request
        base.send :rescue_from, '::ActiveRecord::RecordInvalid', with: :record_invalid  # 400 Bad Request
        base.send :rescue_from, '::ActiveRecord::RecordNotFound', with: :not_found      # 404 Not Found
        base.send :rescue_from, '::ActiveRecord::RecordNotUnique', with: :not_unique    # 409 Conflict
        base.send :rescue_from, '::Paginated::InvalidPaginationOptions', with: :paginated_error   # 400 Bad Request
      end
    end
  end
end
