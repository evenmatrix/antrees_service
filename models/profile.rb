require 'rubygems'
require 'paperclip'
class Profile < ActiveRecord::Base
  include Paperclip::Glue
  UNINITIALIZED = 0
  INITIALIZING = 1
  INITIALIZED = 2
  attr_accessible :first_name, :last_name
  validates :first_name,:last_name, :presence => true , :if=>:initialized?
  has_one :work
  belongs_to :user
  accepts_nested_attributes_for :work
  after_create :update_state_initializing
  has_attached_file :photo,:styles => {:icon=>"50x50#",:thumb => "200x297>", :croppable => '600x600>'},
              :path => ":rails_root/public/system/:attachment/:id/:style/:filename",
              :url => "/system/:attachment/:id/:style/:filename"
  def name
    "#{self.first_name} #{self.last_name}"
  end

  def user_name
    "#{self.first_name}##{self.last_name}#{self.id}"
  end

   def initializing?
      self.current_state == INITIALIZING
   end
  def initialized?
    self.current_state == INITIALIZED
  end

  def update_state_initializing
    self.current_state = INITIALIZING
    self.save
  end

end
