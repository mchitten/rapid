module API
  module Response
    module Errors
      SUCCESS_CODES = %i(
        ok
        created
        accepted
        non_authoritative_information
        no_content
        reset_content
        partial_content
        multi_status
        already_reported
        im_used
      ).freeze

      ERROR_CODES = %i(
        bad_request
        unauthorized
        payment_required
        forbidden
        not_found
        method_not_allowed
        not_acceptable
        proxy_authentication_required
        request_timeout
        conflict
        gone
        length_required
        precondition_failed
        payload_too_large
        uri_too_long
        unsupported_media_type
        range_not_satisfiable
        expectation_failed
        unprocessable_entity
        locked
        failed_dependency
        upgrade_required
        precondition_required
        too_many_requests
        request_header_fields_too_large
      ).freeze

      EXCEPTION_CODES = %i(
        not_implemented
        bad_gateway
        service_unavailable
        gateway_timeout
        http_version_not_supported
        variant_also_negotiates
        insufficient_storage
        loop_detected
        not_extended
        network_authentication_required
      ).freeze

      TYPE_MAP = {
        :SUCCESS_CODES => :message,
        :ERROR_CODES => :errors,
        :EXCEPTION_CODES => :errors
      }.freeze

      %w(SUCCESS ERROR EXCEPTION).each do |type|
        const_get(:"#{type}_CODES").each do |code|
          define_method(:"render_#{code}") do |message = nil|
            message = message.message if message.is_a?(Exception)
            message = nil if message.instance_of?(Exception)
            render_status(message, Rack::Utils.status_code(code), TYPE_MAP[:"#{type}_CODES"])
          end
        end
      end

      private

      def render_status(message, status, envelope = :message)
        render prepare_response(message, envelope: envelope, status: status)
      end

      def render_internal_server_error(e)
        if API.exception_handler
          API.exception_handler.call(e)
        else
          Rails.logger.error e.message
        end

        render_status('Something went wrong', 500, :errors)
      end

      def render_record_invalid(e)
        errors = translate_errors(e.record.errors)
        render_bad_request(errors)
      end

      private

      # Retrieves all errors on an object and maps each error to the specific
      # problematic field.
      #
      # @param errors [Object] An errors object that will be 'translated'.
      #
      def translate_errors(errors, prepend_string = nil)
        # Gets the model that has the errors.
        model = errors.instance_variable_get('@base')

        errors.each_with_object({}) do |(key, error), hsh|
          # Some nested attributes get a weird dot syntax.
          key = key.to_s.split('.').last if key.match(/\./)

          # Retrieves the full error and cleans it as necessary.
          full_message = if key.to_s == 'base'
                           error
                         else
                           col = model.class.human_attribute_name(key)
                           str = ''

                           if prepend_string
                             unless prepend_string.blank?
                               str += "#{prepend_string} "
                             end
                           else
                             str += "#{col} "
                           end

                           str += error
                           (str.slice(0) || '').upcase + (str.slice(1..-1) || '')
                         end

          (hsh[key] ||= []) << full_message
        end
      end

    end
  end
end
