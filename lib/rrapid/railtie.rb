module API
  class Railtie < Rails::Railtie
    initializer 'rrapid.insert_middleware' do |app|
      # Ensure that GZIP is used at the very least for the API.
      app.config.middleware.use Rack::Deflater
    end
  end
end
