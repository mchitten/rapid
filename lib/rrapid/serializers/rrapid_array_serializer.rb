class API::ArraySerializer
  attr_accessor :object, :options
  def initialize(object, options = {})
    @object, @options = object, options
  end

  def warnings(params)
    API::Serializer.warnings(params)
  end

  def as_json(opts = {})
    self.object.map do |i|
      case i.respond_to?(:active_model_serializer)
      when true
        i.active_model_serializer.new(i, options).as_json
      when false
        i.as_json
      end
    end
  end
end
