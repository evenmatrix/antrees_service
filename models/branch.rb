require 'rubygems'
require 'paperclip'
require 'state_machine'

class Branch < ActiveRecord::Base
  include Paperclip::Glue

  attr_accessible :name,:description,:tag_list,:private,:photo;
  validates :name,:presence => true
  validates_uniqueness_of :name,:scope =>:tree_id,:message=>"is already taken."
  has_many :membership_requests, :dependent => :destroy ,:conditions => :private
  belongs_to :tree
  has_many :affiliations,:dependent => :destroy
  has_many :administrations, :dependent => :destroy ,:as=>:entity
  has_many :memberships, :dependent => :destroy ,:as=>:entity
  has_one  :ownership, :dependent => :destroy  ,:as=>:entity
  has_one  :management, :dependent => :destroy  ,:as=>:entity
  has_many :user_presences,:dependent=>:destroy
  has_many :admins, :through => :administrations, :source => :user
  has_many :members, :through => :memberships, :source => :user
  has_one :owner, :through => :ownership, :source => :user
  has_one :manager, :through => :management, :source => :user

  has_many :taggings , :as=>:taggable
  has_many :tags, :through=>:taggings

  has_many :contacts, :dependent=>:destroy

  has_many :tips,:dependent=>:destroy,:conditions => { :published => true }

  has_attached_file :photo,:styles => {:icon=>"50x50#",:icon_2x=>"100x100#",:thumb => "200x297>", :croppable => '600x600>'},
                    :path => ":rails_root/public/system/:attachment/:id/:style/:filename",
                    :url => "/system/:attachment/:id/:style/:filename"

  has_one :caption ,:as => :captionable

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

  def admin?(user, exclude_global_admins=false)
    if user
      if exclude_global_admins
        admins.include? user
      else
        user.admin?(:manage_branches) or admins.include? user
      end
    end
  end

  def last_admin?(user)
    user and admin?(user, :exclude_global_admins) and admins.length == 1
  end


  def self.tagged_with(name)
    Tag.find_by_name!(name).articles
  end

  def self.tag_counts
    Tag.select("tags.*, count(taggings.tag_id) as count").
        joins(:taggings).group("taggings.tag_id")
  end

  def online_contacts
    self.contacts.includes(:user).where(:presence=>"available")
  end

  def tag_list
    if(!tags.empty?)
    tags.map(&:name).join(",")
    else
      ""
    end
  end

  def tag_list=(names)
    self.tags = names.split(",").map do |n|
      logger.info"tag:#{n.strip}"
      Tag.where(name: n.strip).first_or_create!
    end
  end

  def initializing?
    self.state == "initializing"
  end

  def initialized?
    self.state == "initialized"
  end

  def update_state_initializing
    self.initializing
  end
end
