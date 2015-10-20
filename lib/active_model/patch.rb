# We do not recommend that you use AM::S in this way, but if you must, here
# is a mixin that overrides ActiveRecord::Base#to_json and #as_json.

module API
  module Serializable
    def active_model_serializer
      serializer = "#{self.class.name}Serializer".classify

      begin
        serializer.constantize
      rescue NameError
        API::Serializer
      end
    end
  end
end

class Array
  def active_model_serializer
    API::ArraySerializer
  end
end

class ActiveRecord::Relation
  def active_model_serializer
    API::ArraySerializer
  end
end

module ActiveRecord
  class Base
    include API::Serializable
  end
end
