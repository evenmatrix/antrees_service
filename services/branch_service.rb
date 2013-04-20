$LOAD_PATH  << '../lib'
#require "singleton"
require 'rubygems'
require 'active_record'
require 'bundler/setup'
require 'YAML'
require 'logger'

['xpp3','stringprep','dom4j','whack','slf4j-api','slf4j-log4j12','log4j'].each do |name|
  require "#{name}.jar"
end

require_relative '../branch_component'

include Java
import org.jivesoftware.whack.ExternalComponentManager
import org.xmpp.component.ComponentException

class BranchService
  attr_reader   :host,:port

  def initialize(opts={})
    puts "INITIALIZING"
    @host=opts["server_host"]||'rzaartz.local'
    @port=opts["server_port"]||8888
    @sub_domain=opts["sub_domain"]|| 'branch'
    @secret=opts["secret"] || 'secret'
    @env = opts["env"] || "development"
    databases = YAML::load_file(File.join(File.dirname(File.expand_path(__FILE__)),'../config/database.yml'))
    ActiveRecord::ConnectionAdapters::ConnectionManagement
    ActiveRecord::Base.establish_connection(databases[@env])
    @manager = ExternalComponentManager.new @host,@port;
    @opentok_api_key=opts["OPENTOK_API_KEY"]
    @opentok_api_secret=opts["OPENTOK_API_SECRET"]
    @branchComponent = BranchComponent.new @sub_domain,@host,@opentok_api_key,@opentok_api_secret,@env
    @manager.setSecretKey(@sub_domain,@secret);
    @manager.setMultipleAllowed(@sub_domain, true);
    set_up_logger
    @logger.info "#{@host} #{@port} #{@sub_domain}"
  end

  def start
    @logger.info "STARTING"
    begin
    @manager.addComponent @sub_domain,@branchComponent
    rescue ComponentException => e
     @logger.error e
    end
  end

  def stop
    @logger.info "STOPPING"
    begin
    @manager.removeComponent @sub_domain
    rescue ComponentException=>e
      @logger.error e
    end
  end

  def push(data)
    @logger.info "pushed #{data}"
  end

  def set_up_logger
    if @env == "development"
      @logger = TorqueBox::Logger.new( self.class )
    end 
    if @env == "production"
      path = File.join(File.dirname(File.expand_path(__FILE__)), '../log/branch.log')
      file = File.open(path, File::WRONLY | File::APPEND | File::CREAT)
      file.sync = true
      @logger = Logger.new(file)
      @logger.level = Logger::DEBUG
    end
  end

end