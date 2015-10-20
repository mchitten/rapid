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
        #   class UserSerializer < APISerializer
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
        #   class UserSerializer < APISerializer
        #     associations :profile, :avatar
        #     default_associations :profile
        #   end
        #
        # @see associations
        def default_associations(*default_associations)
          Rails.logger.warn "DEPRECATION WARNING: 'default_associations' is deprecated and will be removed soon.  Ask for your associations on a per-endpoint basis."
          self._default_associations = default_associations
        end
      end

      module InstanceMethods
        def serializable_fields
          super
          self._serializable_fields += _get_requested_associations
          self._serializable_fields += _get_default_associations
        end
      end

      def should_be_serialized?(field)
        Array(self.class._associations).include?(field)
      end

      private

      def _get_requested_associations
        requested_associations = Array(options[:params].fetch(:associations, []))
        ra = Array(self.class._associations) & requested_associations.map(&:to_sym)

        return ra #unless API.validate_associations

        # return unless validate_
        # return unless returned.present? &&
        #               requested_associations.length != associations.length

        # bad_associations =
      end

      def _get_default_associations
        Array(self.class._default_associations)
      end
    end
  end
end
