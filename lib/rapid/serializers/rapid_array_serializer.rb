class RapidArraySerializer < ::ActiveModel::ArraySerializer
  attr_accessor :params, :serializer_options
  def initialize(object, options = {})
    super(object, options)

    @serializer_options = options
    @params = options[:params] || {}
    @request = options[:request] || {}
  end

  def warnings(params)
    RapidSerializer.warnings(params)
  end
end
