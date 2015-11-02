# encoding: utf-8

# API configuration.
module API
  class << self
    attr_accessor :validate_associations, :warn_invalid_fields,
                  :show_exceptions, :exception_handler, :envelope,
                  :pretty_print, :jsonp

    def pretty_print
      @pretty_print.nil? ? true : @pretty_print
    end

    def pretty_print?
      pretty_print === true
    end

    def jsonp
      @jsonp.nil? ? true : @jsonp
    end

    def jsonp?
      jsonp === true
    end

    def configure
      yield(self)
    end
  end
end
