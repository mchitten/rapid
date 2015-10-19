class API::ArraySerializer
  include ActiveModel::Serializers::JSON

  attr_accessor :params, :serializer_options
  def initialize(object, options = {})
    @serializer_options = options
    @params = options[:params] || {}
    @request = options[:request] || {}
  end

  def warnings(params)
    API::Serializer.warnings(params)
  end
end
