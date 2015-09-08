module Rapid
  class Railtie < Rails::Railtie
    initializer 'rapid.insert_middleware' do |app|
      # Ensure that GZIP is used at the very least for the API.
      app.config.middleware.use Rack::Deflater
    end
  end
end
