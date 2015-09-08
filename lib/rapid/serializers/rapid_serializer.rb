# encoding: utf-8

class InvalidField < StandardError ; end

# RapidSerializer is the base serializer, providing functionality
# that inherits from and extends ActiveModel::Serializers.  All serializers
# that inherit from RapidSerializer will receive the following (new)
# functionality:
#
# * Optional fields
# * Associations
# * Default associations
# * Request parameter parsing
# * Field inclusion
# * Field exclusion
# * Sub-associations (associations within associations)
# * Sub-fields (fields within associations)
#
# @example
#   class UserSerializer < RapidSerializer
#     attributes :id, :name
#     optional :email
#     associations :avatar
#   end
#
class RapidSerializer < ::ActiveModel::Serializer
  class << self
    attr_accessor :_optional_fields, :_associations, :_default_associations,
                  :_validations, :_options, :_cacheable_fields, :_cache

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
    #   class UserSerializer < RapidSerializer
    #     optional :email, :is_russian
    #   end
    #
    #   # Request like this: /api/v1/users/1?extra_fields[]=email
    def optional(*fields)
      self._optional_fields = fields
    end

    # Associations make it possible to associate a different model with the
    # requested one.  Associations must be explicitly requested (by passing
    # +associations[]=association+), UNLESS the requested association is
    # already a default association.
    #
    # @param associations [Array] A comma-separated list of associations.
    #
    # @example
    #   class UserSerializer < RapidSerializer
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
    #   class UserSerializer < RapidSerializer
    #     associations :profile, :avatar
    #     default_associations :profile
    #   end
    #
    # @see associations
    def default_associations(*default_associations)
      Rails.logger.warn "DEPRECATION WARNING: 'default_associations' is deprecated and will be removed soon.  Ask for your associations on a per-endpoint basis."
      self._default_associations = default_associations
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
    #   class UserSerializer < RapidSerializer
    #     attributes :id, :name, :email
    #     verify_permissions :email, -> { @current_user.can? :update, object rescue false }
    #   end
    #
    #   class UserSerializer < RapidSerializer
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

    # This allows you to cache certain fields within a serializer.  The issue
    # with caching an entire serialized object is that of persistence --
    # a lot of things change, all the time, making it very difficult to cache
    # an entire object and ensure the correct responses.
    #
    # rapid takes a per-field approach to caching.  When an object is
    # serialized, every field is configured to be cached will be cached
    # invididually, allowing for more fine-grained caching abilities.  Each
    # field has a cache key like so:
    #
    #    [object_id].[updated_at]/[field_name]
    #
    # Therefore, making changes to the overlying object will automatically
    # bust the cache for the serialized object and return the new information.
    #
    # +caches+ allows multiple arguments, and may be passed any or all of the
    # following:
    #
    #  * +:all+ will cache every field on the object, including attributes,
    #    optional fields and associations.
    #  * +:associations+ will cache only the associations on an object.  This
    #    is marginally more tricky since associations tend to be an entirely
    #    different object on their own.  In order to properly bust caches on
    #    cached associations, be sure to touch the cached object.
    #  * +:optional_fields+ will cache all optional fields.
    #  * +:fields+ will cache all attributes.
    #  * +:field_name+ will cache the field of name +field_name+, regardless
    #    of what type that field is.  This manes that if the field is an
    #    association, it will be cached.  Likewise, if it is a 'regular'
    #    attribute, it will be cached.
    #
    #  @example
    #    class UserSerializer < RapidSerializer
    #      attributes :first, :last, :email
    #      caches :first, :last
    #    end
    #
    #  @example
    #    class UserSerializer < RapidSerializer
    #      attributes :first, :last, :email
    #      optional :bio
    #      caches :optional_fields
    #    end
    #
    #  @example
    #    class UserSerializer < RapidSerializer
    #      attributes :first, :last, :email
    #      optional :bio
    #      associations :profile
    #      caches :all
    #    end
    #
    #  @param [*args]  A list of cacheable attributes, per the notes above.
    #
    def caches(*attrs)
      fields = []

      if attrs.include? :all
        fields.concat [*self._attributes.keys].map(&:to_sym) +
                      [*self._optional_fields].map(&:to_sym) +
                      [*self._associations].map(&:to_sym)

        attrs.delete(:all)
      end

      if attrs.include? :associations
        fields.concat self._associations
        attrs.delete(:associations)
      end

      if attrs.include? :optional_fields
        fields.concat self._optional_fields
        attrs.delete(:optional_fields)
      end

      if attrs.include? :fields
        fields.concat self._attributes
        attrs.delete(:fields)
      end

      self._cacheable_fields = fields.concat(attrs)
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
    # @see Rapid.configure
    def warnings(params)
      # Ignore unless warn_invalid_fields is set.
      return unless Rapid.warn_invalid_fields

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

  attr_accessor :params, :current_user
  def initialize(object, options = {})
    # Ensure that we're passing around parameters and options.
    @params = options[:params] || {}
    @opts = options
    @current_user = options[:current_user]

    # Give the class access to the options too.
    self.class._options = options

    @params.each do |param, val|
      sp = param.to_sym

      if val.is_a?(Array)
        @opts[sp] ||= []
        @opts[sp].concat val
        @opts[sp] = @opts[sp].flatten.uniq
      else
        @opts[sp] = val
      end
    end

    # Optional fields and associations from the class level.
    @optional = [*self.class._optional_fields]
    @associations = [*self.class._associations]
    @validations = self.class._validations

    [:fields, :only, :extra_fields, :associations].each do |field|
      if @opts[field].is_a? String
        @opts[field] = @opts[field].split(',')
      end
    end

    if @opts[:only].present? || @opts[:fields].present?
      fields = (@opts[:only] || @opts[:fields]).map(&:to_sym)
      assoc_sect = fields & @associations
      if assoc_sect.present?
        @opts[:associations] ||= []
        @opts[:associations].concat assoc_sect
      end

      opt_sect = fields & @optional
      if opt_sect.present?
        @opts[:extra_fields] ||= []
        @opts[:extra_fields].concat opt_sect
      end
    end

    # If we have default associations, join them to the requested ones.
    if self.class._default_associations.present?
      @opts[:associations] ||= []
      @opts[:associations].concat(self.class._default_associations || []) unless @opts[:only].present?

      @opts[:associations]
        .map!(&:to_sym)
        .uniq!
    end

    if object.respond_to?(:id) && object.respond_to?(:updated_at)
      self.class._cache ||= {}
      self.class._cache["#{object.id}.#{object.updated_at.to_i}"] ||= {}
    end

    super
  end

  # There is an +options+ method somewhere in +ActiveModel::Serializer+ that
  # prevents method named "options" from being called correctly.  This fixes
  # that by removing the options scope.
  undef_method(:options)

  # Ovewrwrites +ActiveModel::Serializer#serializable_hash# to allow inclusion
  # and exclusion of specific fields.
  #
  # @see ActiveModel::Serializer#serializable_hash
  def serializable_hash
    attrs = self.class._attributes.dup.keys

    # Inclusive fields.
    if @opts[:only].present? || @opts[:fields].present?
      (@opts[:only] ||= []).concat(@opts[:fields] ||= [])
      attrs = (attrs & @opts[:only].map(&:to_sym))
    # Exclusive fields.
    elsif @opts[:exclude].present?
      attrs = (attrs - @opts[:exclude].map(&:to_sym))
    end

    filter_attributes(attrs)
  end

  # @see RapidSerializer.warnings
  def warnings(params)
    self.class.warnings(params)
  end

  # Returns the correct serializer for an object, or collection of objects
  def self.get_serializer(object)
    if object.respond_to?(:active_model_serializer) &&
       object.try(:active_model_serializer).present?

     serializer = object.active_model_serializer
     if serializer <= ActiveModel::ArraySerializer
       serializer = RapidArraySerializer
     end

     serializer
   else
     nil
   end
  end

  private

  # Returns requested optional fields that are also found in the serializer.
  # @return [Array] An array of valid optional fields.  Invalid fielsd will
  #                 throw a warning.
  def _optional
    @optional & [*@opts[:extra_fields]].map(&:to_sym)
  end

  # Returns requested associations.  This also validates the presence of
  # associations on the request, if configured.
  #
  # @see Rapid.configuration
  #
  # @raises InvalidAssociation
  # @returns [Array] An array of valid associations.
  def _associations
    returned = @associations & [*@opts[:associations]].map(&:to_sym)

    # Stop here unless we want to throw exceptions for bad associations.
    return returned unless Rapid.validate_associations

    # Find invalid associations and throw an exception for them.
    if returned.blank? || returned.length != [*@opts[:associations]].length
      ([*@opts[:associations]].map(&:to_sym) - @associations).each do |assoc|
        fail InvalidAssociation,
             "The '#{assoc}' association does not exist."
      end
    end

    returned
  end

  # Gets information about a specific association.  Associations are links
  # between one serializer and another.
  #
  # You may request associations' fields, associations and optional fields
  # in the request, by specifying +KEY_fields+, +KEY_associations+ or
  # +KEY_extra_fields+, where +KEY+ is the name of the assocation
  # (like 'profile').
  #
  # This will determine if the data is an array or not, and parse it properly.
  #
  # @see associations
  def get_association(data)
    key = data.to_s

    begin
      data = get_field(data, false)
    rescue InvalidField => e
      if Rapid.validate_associations
        raise InvalidAssociation,
              "The '#{data}' association does not exist."
      else
        return
      end
    end

    sub_fields, sub_associations, sub_opts = sub_request_fields(key.to_s)

    sub_options = {}
    sub_options[:only] = sub_fields if sub_fields.present?
    sub_options[:associations] = sub_associations if sub_associations.present?
    sub_options[:extra_fields] = sub_opts if sub_opts.present?
    sub_options[:current_user] = @current_user

    if data.is_a?(Array)
      RapidArraySerializer.new(data, sub_options).as_json(root: false)
    elsif data.respond_to?(:active_model_serializer) && data.try(:active_model_serializer).present?
      data.active_model_serializer.new(data, sub_options).as_json(root: false)
    else
      data.as_json(root: false)
    end
  end

  # Returns a field's information from cache, if possible.
  #
  # @param [String|Symbol] field  The field to retrieve from cache.
  # @return [Mixed] The returned value.
  def _cached_field(field)
    cached_obj = self.class._cache["#{object.id}.#{object.updated_at.to_i}"] || {}
    cached_obj[field]
  end

  # Stores a +field+'s +value+ in cache.
  #
  # @param [String|Symbol] field  The name of the field to store in cache.
  # @param [Mixed] value  The value of that field.
  def _set_cached_field(field, value)
    cached_obj = self.class._cache["#{object.id}.#{object.updated_at.to_i}"] || {}
    cached_obj[field] = Rails.cache.fetch([object.cache_key, field]) { value }
  end

  # Checks whether a certain field is configured to be cached.
  #
  # @param [String|Symbol] field  The field ot ocnfirm configuration on.
  # @return [Boolean]
  # @see caches
  def _cached?(field)
    self.class._cacheable_fields.present? && self.class._cacheable_fields.include?(field.to_sym)
  end

  # Checks whether a certain field is in the cache.
  #
  # @param [String|Symbol] field  The field to check for.
  # @return [Boolean]
  def _in_cache?(field)
    return false if self.class._cache.blank?
    cached_obj = self.class._cache["#{object.id}.#{object.updated_at.to_i}"]
    cached_obj.present? && cached_obj[field].present?
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
    if _cached?(field)
      return _cached_field(field) if _in_cache?(field)
    end

    response = if respond_to?(field)
                 send(field)
               elsif object.respond_to?(field)
                 object.send(field)
               else
                 fail InvalidField, "#{field} could not be found"
               end

    if response.respond_to?(:serializable_hash) && serialize
      response = response.serializable_hash
    end

    if _cached?(field)
      _set_cached_field(field, response)
    else
      response
    end
  end

  # Confirms that a field passes validations.
  #
  # @param field [String|Symbol] The field to check validations on.
  # @return [Bool] True if the viewer can see, false if not.
  def validates?(field)
    return true if @validations.blank?

    # Check if there is a validation at all for this field.
    validation = @validations[field.to_sym]
    return true if validation.blank?

    # Call block
    instance_exec(&validation) === true
  end

  # Filters attributes and returns their values.
  #
  # @param attrs [Array] All of the attributes we need values for.
  # @return [Hash] A hash of key / value pairs.
  def filter_attributes(attrs)
    attributes = attrs.each_with_object({}) do |name, inst|
      next unless validates?(name)
      inst[name] = get_field(name)
    end

    optional_fields = _optional
    if optional_fields.present?
      optional_fields.each do |field|
        next unless validates?(field)
        attributes[field] = get_field(field)
      end
    end

    associated_fields = _associations
    if associated_fields.present?
      associated_fields.each do |assoc|
        next unless validates?(assoc)
        attributes[assoc] = get_association(assoc)
      end
    end

    attributes
  end

  # Returns appropriate sub-fields, sub-associations and/or
  # sub-extra_fields for a particular association.
  #
  # @see get_association
  # @return [Array] an array of fields, associations and optional fields.
  def sub_request_fields(key)
    return unless @opts[:"#{key}_fields"].present? ||
                  @opts[:"#{key}_associations"].present? ||
                  @opts[:"#{key}_extra_fields"].present?

    sub_fields = @opts[:"#{key}_fields"]
    sub_associations = @opts[:"#{key}_associations"]
    sub_opt_fields = @opts[:"#{key}_extra_fields"]

    [sub_fields, sub_associations, sub_opt_fields]
  end
end
