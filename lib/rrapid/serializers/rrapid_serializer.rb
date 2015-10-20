module API
  class Serializer
    include ActiveModel::Serializers::JSON

    require_relative 'helpers/attribute_helpers'
    include AttributeHelpers

    require_relative 'helpers/optional_fields'
    include OptionalFields

    require_relative 'helpers/association_fields'
    include AssociationFields

    attr_reader :object, :options, :current_user
    attr_accessor :_serializable_fields
    def initialize(resource, options = {})
      @object, @options = resource, options
      @current_user = options.fetch(:current_user, nil)
    end

    def self.serializer_for(resource)
      resource.try(:active_model_serializer)
    end

    private

    def serializable_hash(opts = {})
      opts ||= {}
      attribute_names = attributes.map(&:to_s)

      self._serializable_fields = attribute_names

      generate_serialized_hash
    end

    def validates?(attribute)
      validations = self.class._validations

      return true if validations.blank?

      validation = validations[attribute.to_sym]
      return true if validation.blank?

      instance_exec(&validation) === true
    end

    def generate_serialized_hash
      serializable_fields.each_with_object({}) do |attribute, attrs|
        next unless validates?(attribute)
        attrs[attribute] = get_field(attribute)
      end
    end

    # Attempts to get the value of a certain field by first checking the
    # serializer, then the object.  If neither the serializer nor the
    # object respond to the method, raises an +InvalidField+ exception.
    #
    # @param field [String|Symbol] The attribute to get the value for.
    # @param serialize [Boolean]   +get_field+ will attempt to return the
    #                              +serializable_hash+ for any object that is
    #                              returned for a certain attribute.  If this
    #                              is not desirable behavior (say, for
    #                              associations), set this to false.
    #
    # @return [Mixed] Either the value of the attribute, or +InvalidField+ if
    #                 neither the serializer nor the object responds to the
    #                 assumed method.
    def get_field(field, serialize = true)
      response = if respond_to?(field)
                   send(field)
                 elsif object.respond_to?(field)
                   object.send(field)
                 else
                   fail InvalidField, "#{field} could not be found"
                 end

      if should_be_serialized?(field)
        sub_fields, sub_associations, sub_optional_fields = sub_request_fields(field.to_s)

        sub_options = {}
        sub_options[:only] = sub_fields if sub_fields.present?
        sub_options[:associations] = sub_associations if sub_associations.present?
        sub_options[:extra_fields] = sub_optional_fields if sub_optional_fields.present?
        sub_options[:params] = {}

        response = serialize(response, nil, sub_options)
        # serializer = API::Serializer.serializer_for(response)
        # if serializer
        #   response = serializer.new(response, options).as_json(root: false)
        # end
      end

      if response.respond_to?(:serializable_hash) && serialize
        response = response.serializable_hash
      end

      response
    end

    def sub_request_fields(field)
      params = options.fetch(:params, {})
      sub_fields = params[:"#{field}_fields"]
      sub_associations = params[:"#{field}_associations"]
      sub_optional_fields = params[:"#{field}_extra_fields"]

      return {} unless params.present? && (
                      sub_fields.present? ||
                      sub_associations.present? ||
                      sub_optional_fields.present?
                    )

      [sub_fields, sub_associations, sub_optional_fields]
    end
  end
end
