#$LOAD_PATH  << './lib'
require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'torquebox'
require 'active_record'
require 'YAML'

class Service < Sinatra::Base
  include TorqueBox::Injectors
  use TorqueBox::Session::ServletStore

  configure do
    puts "STARTING"
    env =  "development"
    databases = YAML.load_file("config/database.yml")
    ActiveRecord::Base.establish_connection(databases[env])
    #@service= BranchService.instance
    #@service.start
  end

get "/foo"  do
  session[:message] ="Helloworld"
  redirect to("push")
end

get '/push' do
  @branch_service = fetch( 'service:BranchService' )
  @branch_service.push("test")
  session[:message]
end


end

