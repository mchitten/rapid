class API::ArraySerializer < ::ActiveModel::ArraySerializer
  attr_accessor :params, :serializer_options
  def initialize(object, options = {})
    super(object, options)

    @serializer_options = options
    @params = options[:params] || {}
    @request = options[:request] || {}
  end

  def warnings(params)
    API::Serializer.warnings(params)
  end
end
