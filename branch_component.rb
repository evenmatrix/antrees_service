require 'rubygems'
require 'redis'
require 'json'
require 'opentok'
require "#{File.dirname(__FILE__)}/models/user"
require "#{File.dirname(__FILE__)}/models/branch"
require "#{File.dirname(__FILE__)}/models/contact"
require "#{File.dirname(__FILE__)}/models/affiliation"
require "#{File.dirname(__FILE__)}/models/call"
include Java
import org.xmpp.component.AbstractComponent
import org.xmpp.packet.IQ
import org.xmpp.packet.JID
import org.xmpp.packet.Presence
import org.xmpp.packet.Message
import org.xmpp.packet.PacketError::Condition
import org.xmpp.component.ComponentException
import org.dom4j.Element;

class  BranchComponent <  AbstractComponent
  @active_branches
  @active_users

  NS_MUC= 'http://jabber.org/protocol/muc'
  NS_RTC_SESSION_INIT='http://antrees.com/rtc/session_init'
  NS_CALL_SETUP='http://antrees.com/call_setup'
  NS_ROSTER ='jabber:iq:roster'
  NS_CALL_INVITE='http://antrees.com/call_invite'

  def initialize(name=nil,server_domain=nil,opentok_key=nil,opentok_secret=nil,env="development")
    super(false)
    @name=name
    @server_domain=server_domain
    @domain="branch.#{@server_domain}"
    @jid=nil
    @env=env
    @component_manager=nil
    @last_start_millis=nil
    @opentok_api_key=opentok_key
    @opentok_api_secret=opentok_secret
    @location="localhost"
    @OTSDK = OpenTok::OpenTokSDK.new @opentok_api_key,@opentok_api_secret
    # Creating Session object with p2p enabled
    @sessionProperties = {OpenTok::SessionPropertyConstants::P2P_PREFERENCE => "enabled"}
    #@redis =Redis.new(:host => 'localhost', :port => 6379)
    set_up_logger
  end

  def init(jid,component_manager)
    @jid=jid
    @component_manager=component_manager
    @logger.info "inited #{@component_manager}"
  end

  def getName
    @name
  end

  def getDomain
    @domain
  end

  protected

  def handleMessage (message)
    begin
      if (message.type == Message::Type::chat)
        handle_chat_message(message)
      elsif(message.type == Message::Type::error)
        handle_error_message(message)
      elsif(message.type == Message::Type::groupchat)
        handle_group_chat_message(message)
      end
    rescue Exception => e
      @logger.error "Error :,#{e.message}"
      @logger.error $!.backtrace.collect { |b| " > #{b}" }.join("\n")
    ensure
      close_connection
    end
  end

  def handle_chat_message(message)
    @logger.info "received #{message.type}"
    @logger.info "message: #{message.to_xml}"
    to = message.to;
    from=  message.from
    from_id=from.node
    to_id = to.resource;
    branch_id= to.node
    recepient=User.includes(:contact).find(to_id)
    jid=recepient.contact.jid
    if(!jid.nil?)
      from_jid= JID.new(branch_id,@domain,from_id)
      message.to=jid
      message.from=from_jid
      send(message)
    end
  end

  def handle_error_message(message)
    @logger.info "received #{message.type}"
    @logger.info "message: #{message.to_xml}"
  end

  def handle_group_chat_message(message)
    @logger.info "received #{message.type}"
    @logger.info "message: #{message.to_xml}"
    to = message.to;
    from=  message.from
    from_id=from.node
    to_id = to.resource;
    branch_id= to.node
    branch= Branch.find(branch_id)
    if(branch)
    branch.online_contacts.each do |contact|
      if(from_id!=contact.user_id.to_s)
        jid=contact.jid
          if(!jid.nil?)
            from_jid= JID.new(branch_id,@domain,from_id)
            message.to=jid
            message.from=from_jid
            send(message)
       end
    end
      end
    end
  end

  def handlePresence(presence)
       begin
         if (presence.type == Presence::Type::unavailable)
         handle_unavailable_presence(presence)
       elsif(presence.type == Presence::Type::error)
         handle_presence_error(presence)
       else
         handle_available_presence(presence)
       end
       rescue Exception => e
         @logger.error "Error :,#{e.message}"
         @logger.error $!.backtrace.collect { |b| " > #{b}" }.join("\n")
       ensure
         close_connection
       end
  end

  def handleIQResult(iq)
    @logger.info "IQ result"
  end

  def handleIQError(iq)
  end

  def handleIQGet(iq)
    begin
      @logger.info "iq to #{iq.to}"
      @logger.info "iq from:#{iq.from}"
      elem=iq.child_element
      name=elem.name
      result=nil
      if name=="query"
        result=doQuery(iq)
      elsif name=="rtc"
        result=rtc_get(iq)
      end
      result
    rescue Exception => e
      @logger.error "Error :,#{e.message}"
      @logger.error $!.backtrace.collect { |b| " > #{b}" }.join("\n")
    ensure
      close_connection
    end
  end
 
  def handleIQSet(iq)
      begin
        @logger.info "iq  #{iq.to_xml}"
        elem=iq.child_element
        name=elem.name
        result=nil
        if name=="call-init"
          result=call_init iq
        end
        if name=="call-reject"
          result=call_reject iq
        end
        if name=="call-terminate"
          result=call_terminate iq
        end                
        if name=="call-accept"
          result=call_accept iq
        end
        result
      rescue Exception => e
        @logger.error "Error :,#{e.message}"
        @logger.error $!.backtrace.collect { |b| " > #{b}" }.join("\n")
      ensure
        close_connection
      end
  end
  
  def doQuery(iq)
    @logger.info "to #{iq.to}"
    @logger.info "from:#{iq.from}"
    to = iq.to;
    from= iq.from
    user_id = from.node;
    branch_id = to.node
    user= User.find(user_id)
    branch=Branch.find(branch_id)
    result=IQ::createResultIQ iq
    if(user && branch)
      if(user.can_see?(branch))
        elem=iq.child_element
        namespace=elem.namespace_uri
        @logger.info "namespace #{elem.namespace_uri}"
        if namespace == NS_ROSTER
          elem = result.set_child_element("query",NS_ROSTER);
          online_contacts=branch.online_contacts
          online_contacts.each do |contact|
            @logger.info "contact.user_id #{contact.user_id} != user_id #{user_id} #{contact.user_id.to_s != user_id}"
            if(contact.user_id != user.id)
               add_item_attributes(elem.add_element("item"),contact)
            end
          end
        end
      end
      end
    result
  end

  def call_init(iq)
    to = iq.to;
    branch_id= to.node
    branch=Branch.find(branch_id)
    result=nil
    elem=iq.child_element
    namespace=elem.namespace_uri
    @logger.info "namespace #{elem.namespace_uri}"
    if namespace == NS_CALL_SETUP
      caller_id=elem.attribute_value("caller_id")
      callee_id=elem.attribute_value("callee_id")
      caller= User.includes(:contact).find(caller_id)
      callee= User.includes(:contact).find(callee_id)
      if((caller && callee) && (callee.contact))
        if((caller.contact.branch==branch)&&(branch==callee.contact.branch))
          @logger.info "same branch"
          #check_to see if callee has a call with caller
          if(Call.existing_call?(callee,caller,branch))
            result=create_error iq,Condition::not_allowed 
            @logger.info "existing call from callee to caller #{result.to_xml}"
            Call.existing_call(callee,caller,branch).delete
            return result
          end
          if(Call.existing_call?(caller,callee,branch))
            result=create_error iq,Condition::not_allowed 
            @logger.info "existing call from caller to callee #{result.to_xml}"
            #return error callee is trying to call caller
            Call.existing_call(caller,callee,branch).delete
            return result
          end
          call=Call.new
          call.caller=caller
          call.branch=branch
          call.callee=callee
          sessionId = @OTSDK.createSession( "", @sessionProperties )
          token = @OTSDK.generateToken :session_id =>sessionId, :role => OpenTok::RoleConstants::PUBLISHER
          call.sid=sessionId.to_s#Call.session_id#
          call.token=token.to_s#Call.token#
          saved=call.save
          call.offer
          result=IQ::createResultIQ iq
          child =result.set_child_element "call-setup",NS_CALL_SETUP
          child.add_attribute "sid",call.sid
          child.add_attribute "token",call.token
          callee_jid=callee.contact.jid
          caller_jid= JID.new(branch.id.to_s,@domain,caller_id)
          inv_iq=IQ.new(IQ::Type::set)
          inv_iq.to=callee_jid
          inv_iq.from=to
          inv_el =inv_iq.set_child_element "call-invite",NS_CALL_SETUP
          inv_el.add_attribute "sid",call.sid
          inv_el.add_attribute "token",call.token
          inv_el.add_attribute "from",caller_jid.to_s
          @logger.info "inv_iq: #{inv_iq.to_xml}" 
          inv_result=@component_manager.query(self,inv_iq,3000)
          if(inv_result)
            @logger.info "received ack: #{inv_result.to_xml}" 
          else
             call.delete
             result=create_error iq,Condition::recipient_unavailable
          end
          #send invite to remote peer
          @logger.info "result: #{result.to_xml}" 
        else 
          #permission-error
          result=create_error iq,Condition::forbidden  
          @logger.info "permission erron: not on the same branch"
          end
      else
        #not-found-error
        result=create_error iq,Condition::item_not_found 
        @logger.info "callee not found #{result.to_xml}"
      end   
    end
    result   
  end
  
  def call_accept(iq)
    to = iq.to;
    branch_id= to.node
    branch=Branch.find(branch_id)
    result=nil
    elem=iq.child_element
    namespace=elem.namespace_uri
    @logger.info "accept namespace #{elem.namespace_uri}"
    if namespace == NS_CALL_SETUP
      sid=elem.attribute_value("sid")
      call= Call.find_by_sid(sid)
      if(call&&call.caller.contact)
        caller=call.caller
        accept_iq=IQ.new(IQ::Type::set)
        accept_iq.to=caller.contact.jid
        accept_iq.from=to
        elem =accept_iq.set_child_element "call-accept",NS_CALL_SETUP
        elem.add_attribute "sid",call.sid.to_s
        @logger.info "accept_iq: #{accept_iq.to_xml}" 
        acc_result=@component_manager.query(self,accept_iq,3000)
        if(acc_result)
          @logger.info "received ack: #{acc_result.to_xml}" 
          result=IQ::createResultIQ iq
          child =result.set_child_element "call-accept",NS_CALL_SETUP
          child.add_attribute "sid",call.sid.to_s
          call.answer
        else
          call.delete
          result=create_error iq,Condition::recipient_unavailable
        end
      else
        result=create_error iq,Condition::forbidden
      end
    end
    result   
  end
  
  def call_reject(iq)
    to = iq.to;
    user= User.find(iq.from.node)
    branch_id= to.node
    branch=Branch.find(branch_id)
    result=nil
    elem=iq.child_element
    namespace=elem.namespace_uri
    @logger.info "accept namespace #{elem.namespace_uri}"
    if namespace == NS_CALL_SETUP
      sid=elem.attribute_value("sid")
      call= Call.find_by_sid(sid)
      if(call) 
        if(call.isCallee?(user))
        if(call.caller.contact)
          caller=call.caller
          reject_iq=IQ.new(IQ::Type::set)
          reject_iq.to=caller.contact.jid
          reject_iq.from=to
          elem =reject_iq.set_child_element "call-reject",NS_CALL_SETUP
          elem.add_attribute "sid",call.sid.to_s
          @logger.info "reject_iq: #{reject_iq.to_xml}" 
          @component_manager.query(self,reject_iq,3000) 
          result=IQ::createResultIQ iq
          child =result.set_child_element "call-reject",NS_CALL_SETUP
          child.add_attribute "sid",call.sid.to_s
          call.destroy
        end
          else
            result=create_error iq,Condition::forbidden 
        end
      else
        result=create_error iq,Condition::item_not_found
      end
    end
    result   
  end
  
  def call_terminate(iq)
    to = iq.to;
    user= User.find(iq.from.node)
    branch_id= to.node
    branch=Branch.find(branch_id)
    result=nil
    elem=iq.child_element
    namespace=elem.namespace_uri
    @logger.info "accept namespace #{elem.namespace_uri}"
    if namespace == NS_CALL_SETUP
      sid=elem.attribute_value("sid")
      call= Call.find_by_sid(sid)
      if(call)
      if(call.isCaller?(user)||call.isCallee?(user)) 
        if(call.isCaller?(user) && call.callee.contact)
          callee=call.callee
          terminate_iq=create_call_iq(callee.contact.jid,to,IQ::Type::set)
          elem =terminate_iq.set_child_element "call-terminate",NS_CALL_SETUP
          elem.add_attribute "sid",call.sid.to_s
          @logger.info "terminate_iq: #{terminate_iq.to_xml}" 
          @component_manager.query(self,terminate_iq,3000) 
          result=IQ::createResultIQ iq
          child =result.set_child_element "call-terminate",NS_CALL_SETUP
          child.add_attribute "sid",call.sid.to_s
          call.destroy        
        end
        if(call.isCallee?(user) && call.caller.contact)
          caller=call.caller
          terminate_iq=create_call_iq(caller.contact.jid,to,IQ::Type::set)
          elem =terminate_iq.set_child_element "call-terminate",NS_CALL_SETUP
          elem.add_attribute "sid",call.sid.to_s
          @logger.info "reject_iq: #{terminate_iq.to_xml}" 
          @component_manager.query(self,terminate_iq,3000) 
          result=IQ::createResultIQ iq
          child =result.set_child_element "call-terminate",NS_CALL_SETUP
          child.add_attribute "sid",call.sid.to_s
          call.destroy         
        end 
          else
            result=create_error iq,Condition::forbidden 
          end
        else
        result=create_error iq,Condition::item_not_found         
      end
    end
    result   
  end
 
 def terminate_user_calls(user,branch)
   from=JID.new(branch.id.to_s,@domain,user.id.to_s)
   calls=Call.user_calls(user,branch)
   calls.each do |call|
     callee=call.callee
     caller=call.caller
     send_terminate(call,callee,from) 
     send_terminate(call,caller,from)
     call.destroy
   end
 end
 
 def send_terminate(call,who,from)
   terminate_iq=create_call_iq(who.contact.jid,from,IQ::Type::set)
   elem =terminate_iq.set_child_element "call-terminate",NS_CALL_SETUP
   elem.add_attribute "sid",call.sid.to_s
   @component_manager.query(self,terminate_iq,1000) 
   @logger.info "terminate_iq: #{terminate_iq.to_xml}"   
 end
 
 def create_call_iq(to,from,type)
   iq=IQ.new(type)
   iq.to=to
   iq.from=from
   iq  
 end 
  def rtc_get(iq)
    result=nil
    elem=iq.child_element
    namespace=elem.namespace_uri
    @logger.info "namespace #{elem.namespace_uri}"
    if namespace == NS_RTC_SESSION_INIT
       child =result.set_child_element("rtc",NS_RTC_SESSION_INIT);
       @logger.info "child nil? #{child.nil?}"
       sessionId = @OTSDK.createSession( "", @sessionProperties )
       token = @OTSDK.generateToken :session_id =>sessionId, :role => OpenTok::RoleConstants::PUBLISHER
       child.add_attribute "sid",sessionId.to_s
       child.add_attribute "token",token.to_s
       @logger.info "result: #{result.to_xml}"    
    end
    result
  end
  


  def handle_unavailable_presence(presence)
    @logger.info "to #{presence.to}"
    @logger.info "from:#{presence.from}"
    @logger.info "presence_type:#{presence.type}"
    to = presence.to;
    from=  presence.from
    user_id = to.resource;
    branch_id= to.node
    user= User.find(user_id)
    branch=Branch.find(branch_id)
    @logger.info "unavailable #{presence.from}"
    deleted=@redis.srem("branch:#{branch_id}:jids",from.to_s)
    @logger.info "deleted #{deleted}"
    contact=user.contact
    terminate_user_calls(user,branch)
    if(contact)
      if(contact.jid == presence.from.to_s)
        remove_contact_from_cache(contact)
        contact.delete
        notify_contacts_for_branch(branch,contact,Presence::Type::unavailable)
      end
    end
  end

  def handle_available_presence(presence)
      @logger.info "presence_type:#{presence.type}"
      to = presence.to;
      from=  presence.from
      user_id = to.resource;
      branch_id= to.node
      user= User.find(user_id)
      branch=Branch.find(branch_id)
      @logger.info "available #{presence.from}"
      @logger.info "@user #{user_id}"
      @logger.info "@branch #{branch_id}"
      contact=nil
      if(user.can_see?(branch))
        @logger.info "user_id #{user_id}"
        contact=Contact.new({:jid=>from.to_s})
        contact.presence="available"
        contact.branch=branch
        affiliation=user.affiliations.where(:entity_id=>branch).first
        contact.affiliation=map_type_to_affiliation(affiliation)
        @logger.info "AFFILIATION #{ contact.affiliation}"
        user.contact=contact
        saved=user.save
        @logger.info "saved new contact #{saved}"
        add_contact_to_cache(contact)
        notify_contacts_for_branch(branch,contact,nil)
      end
  end

  def handle_presence_error(presence)
  end

  def notify_contacts_for_branch(branch,new_contact,type=nil)
    from=JID.new(branch.id.to_s,@domain,new_contact.user_id.to_s)
    branch.online_contacts.each do |contact|
      if(contact.id!=new_contact.id)
        presence=create_presence(from,JID.new(contact.jid),type,new_contact)
        send presence
        @logger.debug "user:#{new_contact.user_id}==>contact:#{contact.id}"
        @logger.debug presence.to_xml
        end
    end
  end


  def add_item_attributes(item,contact)
    item.add_attribute "name",contact.user.name
    item.add_attribute "photo_url",contact.user.photo.url(:icon)
    item.add_attribute "jid",JID.new(contact.branch_id.to_s,@domain,contact.user_id.to_s).to_s
    item.add_attribute "affiliation",contact.affiliation
  end

  def create_presence(from,to,type,contact)
    presence=Presence.new
    presence.from=from
    presence.to=to
    presence.type=type
    elem = presence.add_child_element("x",NS_MUC);
    item=elem.add_element("item");
    add_item_attributes(item,contact)
    presence
  end

  def add_presence_item(presence,contact)

  end

 def send(packet)
    begin
    @component_manager.send_packet(self, packet);
    rescue ComponentException => e
      @logger.error "Error :,#{e.message}"
      @logger.error $!.backtrace.collect { |b| " > #{b}" }.join("\n")
    end

 end

  def close_connection
    ActiveRecord::Base.connection.close
  end

  def open_connection
    databases = YAML.load_file("../gutrees/config/database.yml")
    ActiveRecord::Base.establish_connection(databases["development"])
  end

  def add_contact_to_cache(contact)
    #@redis.sadd("branch:#{branch_id}:jids",contact.jid)
    #@redis.sadd("branch:#{contact.branch_id}:contacts",contact.user_id)
    #@redis.hset("branch:#{contact.branch_id}:contacts:#{contact.user_id}","jid",contact.jid)
  end

  def remove_contact_from_cache(contact)
     #@redis.del("branch:#{contact.branch_id}:contacts:#{contact.user_id}")
     #@redis.srem("branch:#{contact.branch_id}:contacts",contact.user_id)
     #@redis.srem("branch:#{contact.branch_id}:jids",contact.jid)
  end

  def get_jid_from_cache(branch_id,user_id)
      #@redis.hget("branch:#{branch_id}:contacts:#{user_id}","jid")
  end
  
  def map_type_to_affiliation(affiliation)
    if(affiliation)
      role = case affiliation.type
               when "Administration"
                 "admin"
               when "Membership"
                 "member"
               else
                 "visitor"
             end
    else
      "visitor"
    end
  end

  def create_error(iq,condition)
    result = IQ.new(IQ::Type::error, iq.id);
    result.from=iq.to
    result.to=iq.from
    result.error=condition
    result
  end
  
  def set_up_logger
    if @env == "development"
      @logger = TorqueBox::Logger.new( self.class )
    end 
    if @env == "production"
      path = File.join(File.dirname(File.expand_path(__FILE__)), 'log/branch.log')
      file = File.open(path, File::WRONLY | File::APPEND | File::CREAT)
      file.sync = true
      @logger = Logger.new(file)
      @logger.level = Logger::DEBUG
    end
  end
end