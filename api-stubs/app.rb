require "sinatra/base"
require "json"
require 'sequel'
require 'sqlite3'

DB_AUTH = Sequel.connect(adapter: 'sqlite', database: ENV.fetch("AUTH_DB"))
DB_LOGGING = Sequel.connect(adapter: 'sqlite', database: ENV.fetch("LOGGING_DB"))

class AuthLine < Sequel::Model(DB_AUTH[:lines])
end

class LoggingLine < Sequel::Model(DB_LOGGING[:lines])
end

class ApiStub < Sinatra::Base
  configure do
    set :port, 80
  end

  get "/authorize/user/*" do
    AuthLine.create(line: request.path_info)
    content_type :json
    { "control:Cleartext-Password": ENV["HEALTH_CHECK_PASSWORD"] }.to_json
  end

  post "/logging/post-auth" do
    LoggingLine.create(JSON.parse(request.body.read))
    content_type :json
    status 204
  end

  get "/healthcheck" do
    status 200
  end

end
