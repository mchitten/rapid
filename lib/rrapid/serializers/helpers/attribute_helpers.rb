module API
  class Serializer
    module AttributeHelpers
      def self.included(base)
        base.extend ClassMethods
        base.include InstanceMethods
      end

      module ClassMethods
        attr_accessor :_attributes, :_validations

        def attributes(*fields)
          self._attributes = fields
        end

        # This will ensure that content is secure by validating the passed block,
        # and only showing an attribute's content if the block returns +true+.  If
        # the block does not return +true+, this attribute's value will be +null+.
        #
        # @param attribute [Symbol or Array] The attribute(s) to run permission checks on.
        # @param validation [Block] A block that will be run to verify that the
        #                           viewing party has permission to see the
        #                           attribute.
        #
        # @example
        #   class UserSerializer < APISerializer
        #     attributes :id, :name, :email
        #     verify_permissions :email, -> { @current_user.can? :update, object rescue false }
        #   end
        #
        #   class UserSerializer < APISerializer
        #     attributes :id, :name, :email
        #     verify_permissions [:name, :email] do
        #       @current_user.can? :update, object rescue false
        #     end
        #   end
        #
        # @see validates?
        def verify_permissions(attributes, validation = nil, &block)
          attributes = [attributes] unless attributes.is_a? Array
          self._validations ||= {}
          attributes.each do |attribute|
            self._validations[attribute] = (validation.present? ? validation : block)
          end
        end

        # Returns warnings about your request. Warnings are messages that alert
        # you to things that are wrong, but not breaking.  In this initial release,
        # warnings are only triggered by requesting optional fields that do not
        # exist in the serializer.
        #
        # Warnings will be returned as an array at the end of the payload with the
        # key 'warnings'.
        #
        # Warnings must be enabled through the +warn_invalid_fields+ configuration
        # option.
        #
        # @param params [Hashie] The params object that is passed around in Rails.
        #
        # @return [Array] An array of warnings.
        #
        # @example
        #   # GET /api/v1/users/1?extra_fields[]=asdfg
        #
        #   {
        #     "data": {
        #       ...
        #     },
        #     "warnings": [
        #       "The optional field 'asdfg' does not exist."
        #     ]
        #   }
        #
        # @see API.configure
        def warnings(params)
          # Ignore unless warn_invalid_fields is set.
          return unless API.warn_invalid_fields

          # Basic information about the request.
          params = params.symbolize_keys
          req_fields = [*params[:extra_fields]].map(&:to_sym)
          klass_fields = [*_optional_fields]

          good_fields = klass_fields & req_fields
          bad_fields = (req_fields - klass_fields)

          # Find any invalid fields and add a message.
          bad = bad_fields.reduce([]) do |w, f|
            w << "The '#{f}' field is not a valid optional field"
          end if good_fields.blank? || good_fields.length != req_fields.length

          # Return the warnings.
          bad
        end
      end

      module InstanceMethods
        def serializable_fields
          fields = _serializable_fields

          only = options.fetch(:params, {}).fetch(:only, []).presence || options.fetch(:only, [])
          except = options.fetch(:params, {}).fetch(:except, []).presence || options.fetch(:except, [])

          if only.present?
            fields &= Array(only).map(&:to_s)
          elsif except.present?
            fields -= Array(except).map(&:to_s)
          end

          self._serializable_fields = fields
        end

        def attributes
          Hash[
            (self.class._attributes.presence || object.attributes.keys).map do |field|
              field.is_a?(Hash) ? Array(field)[0] : [field, field]
            end
          ]
        end
      end
    end
  end
end
