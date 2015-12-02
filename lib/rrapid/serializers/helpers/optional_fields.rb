module API
  class Serializer
    module OptionalFields
      def self.included(base)
        base.extend ClassMethods
        base.include InstanceMethods
      end

      module ClassMethods
        attr_accessor :_optional_fields

        # Optional fields assigned to this serializer.  Optional fields need to
        # be explicitly requested (by passing +extra_fields[]=field+) to be
        # returned in the payload.
        #
        # Optional fields will return warnings if configured, and the requester
        # asks for fields that do not exist in the serializer.
        #
        # @param fields [Array] A comma-separated list of fields that are optional.
        #
        # @example
        #   class UserSerializer < API::Serializer
        #     optional :email, :is_russian
        #   end
        #
        #   # Request like this: /api/v1/users/1?extra_fields[]=email
        def optional(*fields)
          self._optional_fields = fields
        end
      end

      module InstanceMethods
        def serializable_fields
          super
          self._serializable_fields += _get_optional_fields_from_options
          self._serializable_fields += _get_requested_optional_fields
        end
      end

      private

      def _get_optional_fields_from_options
        optional_fields = options.fetch(:extra_fields, [])
        optional_fields = optional_fields.split(',') unless optional_fields.is_a?(Array)
        Array(self.class._optional_fields) & optional_fields.map(&:to_sym)
      end

      def _get_requested_optional_fields
        requested_optional_fields = options.fetch(:params, {}).fetch(:extra_fields, [])
        requested_optional_fields = requested_optional_fields.split(',') unless requested_optional_fields.is_a?(Array)
        Array(self.class._optional_fields) & requested_optional_fields.map(&:to_sym)
      end
    end
  end
end
