require 'rubygems'
require 'paperclip'
require 'state_machine'

class User < ActiveRecord::Base
  include Paperclip::Glue
  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation,:remember_me ,:first_name, :last_name ,:photo
  validates :first_name,:last_name, :presence => true , :if=>:initialized?

  has_many :memberships, :dependent => :destroy
  has_many :branches, :through => :memberships
  has_many :affiliations, :dependent => :destroy

  belongs_to :admin

  has_attached_file :photo,:styles => {:icon=>"50x50#",:thumb => "200x297>", :croppable => '600x600>'},
                    :path => ":rails_root/public/system/:attachment/:id/:style/:filename",
                    :url => "/system/:attachment/:id/:style/:filename"

  has_one :caption ,:as => :captionable

  has_many :sent_messaqes,:foreign_key => "sender_id",:class_name => "Message"
  has_many :received_messaqes,:class_name => "Message",:as=>:polymorphic

  has_one :contact,:dependent=>:destroy

  after_create :create_tree

  after_create :update_state_initializing

  state_machine initial: :uninitialized   do

    event :initialized do
      transition :initializing => :initialized
    end

    event :initializing do
      transition :uninitialized => :initializing
      transition :initialized => :initializing
    end

    event :uninitialized do
      transition :initializing => :uninitialized
      transition :initialized => :uninitialized
    end
  end

  def self.find_for_google_oauth2(access_token, signed_in_resource=nil)
    data = access_token.info
    user = User.where(:email => data["email"]).first

    unless user
      user = User.create(name: data["name"],
                         email: data["email"],
                         password: Devise.friendly_token[0,20],
                         image: data["image"]
      )
    end
    user
  end



  def member_of?(entity)
    memberships.find_by_entity_id(entity.id)
  end

  def can_see?(*whats)
    whats.select do |what|
      case what.class.name
        when 'Branch'
          not (what.private?) or self.member_of?(what) or what.admin?(self)
        when 'Tree'
          not (what.private?) or self.member_of?(what) or what.admin?(self)
        else
          raise "Unrecognized argument to can_see? (#{what.inspect})"
      end
    end.length == whats.length
  end

  alias_method :sees?, :can_see?




  def can_edit?(what)
    case what.class.name
      when 'Branch'
        what.admin?(self) or self.admin?(:manage_groups) or self.can_edit?(what.tree)
      when 'Tree'
        what.admin?(self) or self.admin?(:manage_groups)
      when 'Membership'
        self.admin?(:manage_groups) or (what.entity and what.entity.admin?(self)) or self.can_edit?(what.entity)
      else
        raise "Unrecognized argument to can_edit? (#{what.inspect})"
    end
  end

  def admin?(perm=nil)
    if perm
      admin and admin.flags[perm.to_s]
    else
      admin ? true : false
    end
  end

  def tree
    domain=self.email.split("@").last
    tree=Tree.find_by_domain domain
  end

  def name
    "#{self.first_name} #{self.last_name}"
  end

  def user_name
    "#{self.first_name}##{self.last_name}#{self.id}"
  end

  def initializing?
    self.state == "initializing"
  end

  def initialized?
    self.state == "initialized"
  end

  def update_state_initializing
    initializing
  end

  private

  def create_tree
    #is there a tree registered with this current_user domain?
    #if so add this user to the trees member list and  show home
    #if not create a tree with this domain, add the user as admin and redirect to trees
    #at this point, the tree is in the uninitialized state which should cause the tree's show to
    #redirect to the tree's setup page.
    domain=self.email.split("@").last
    tree=Tree.find_by_domain domain

    if tree
      membership=Affiliation::Membership.new
      membership.user=self
      tree.memberships<<membership
      tree.save
    else
       tree=Tree.new
       tree.domain=domain
       administration=Affiliation::Administration.new
       administration.user=self
       tree.administrations<<administration
       tree.save
    end
  end

end
