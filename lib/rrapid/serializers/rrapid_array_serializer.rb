class API::ArraySerializer
  attr_accessor :object, :options
  def initialize(object, options = {})
    @object, @options = object, options
  end

  def warnings(params)
    API::Serializer.warnings(params)
  end

  def as_json(opts = {})
    response = self.object.map do |i|
      if i.respond_to?(:active_model_serializer)
        i.active_model_serializer.new(i, options.merge(key: nil)).as_json
      else
        i.as_json
      end
    end

    key = if options.key?(:key)
            options[:key]
          elsif object.respond_to?(:model)
            object.model.new.active_model_serializer._key
          else
            if object.length > 1
              object.first.try(:active_model_serializer).try(:_key)
            end
          end

    key = key[:multiple] if key.is_a?(Hash)

    return response unless key.present?

    { key => response }
  end
end
