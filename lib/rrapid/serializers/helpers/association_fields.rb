module API
  class Serializer
    module AssociationFields
      def self.included(base)
        base.extend ClassMethods
        base.include InstanceMethods
      end

      module ClassMethods
        attr_accessor :_associations, :_default_associations

        # Associations make it possible to associate a different model with the
        # requested one.  Associations must be explicitly requested (by passing
        # +associations[]=association+), UNLESS the requested association is
        # already a default association.
        #
        # @param associations [Array] A comma-separated list of associations.
        #
        # @example
        #   class UserSerializer < API::Serializer
        #     associations :profile
        #   end
        #
        #   # request like this: /api/v1/users/1?associations[]=profile
        #
        # @see default_associations
        def associations(*associations)
          self._associations = associations
        end

        # Default associations are associations that will show up in the payload,
        # regardless of whether or not you ask for them.  Default associations
        # are generally used for information that is requested more often than not.
        #
        # Default associations must be valid associations.
        #
        # @param default_associations [Array] A comma-separated list of associations
        #                                     that should always show up.
        # @example
        #   class UserSerializer < API::Serializer
        #     associations :profile, :avatar
        #     default_associations :profile
        #   end
        #
        # @see associations
        def default_associations(*default_associations)
          self._default_associations = default_associations
        end
      end

      module InstanceMethods
        def serializable_fields
          super
          self._serializable_fields += _get_associations_from_options
          self._serializable_fields += _get_requested_associations
          self._serializable_fields += _get_default_associations
        end
      end

      def should_be_serialized?(field)
        Array(self.class._associations).include?(field)
      end

      private

      def _get_associations_from_options
        associations = Array(options.fetch(:associations, []))
        Array(self.class._associations) & associations.map(&:to_sym)
      end

      def _get_requested_associations
        requested_associations = Array(options.fetch(:params, {}).fetch(:associations, []))
        returned = Array(self.class._associations) & requested_associations.map(&:to_sym)

        return returned unless API.validate_associations

        bad_associations = requested_associations - returned
        return unless bad_associations.present?

        fail InvalidAssociation, "The %s association does not exist." % bad_associations.map { |a| "'#{a}'" }.to_sentence
      end

      def _get_default_associations
        Array(self.class._default_associations)
      end
    end
  end
end
