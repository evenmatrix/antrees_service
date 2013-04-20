require 'torquebox-capistrano-support'
require 'bundler/capistrano'

load "config/recipes/base"
load "config/recipes/branch"
load "config/recipes/postgresql"

server "198.199.75.76", :web, :app, :db, primary: true

# SCM
set :deployer, "deployer"
set :application,"antrees"
set :user, "root"
set :scm, "git"
set :repository, "git@github.com:evenmatrix/#{application}.git"
set :scm_verbose,       true
set :use_sudo,          false
set :branch, "master"

# Production server
set :deploy_to, "/home/#{deployer}/apps/#{application}"
set :torquebox_home,    "/opt/torquebox/current"
set :jboss_init_script, "/etc/init.d/jboss-as-standalone"
set :app_environment,   "RAILS_ENV: production"
set :app_context,       "/"

default_run_options[:pty] = true
ssh_options[:forward_agent] = true

after "deploy", "deploy:cleanup"

