require 'torquebox-capistrano-support'
require 'bundler/capistrano'

load "config/recipes/base"
load "config/recipes/branch"
load "config/recipes/postgresql"

server "antrees.com", :web, :app, :db, primary: true

# SCM
set :deployer, "deployer"
set :application,"antrees_service"
set :user, "root"
set :scm, "git"
set :repository, "git@github.com:evenmatrix/#{application}.git"
set :scm_verbose,       true
set :use_sudo,          false
set :branch, "master"

# Production server
set :deploy_to, "/home/#{deployer}/apps/#{application}"
set :jboss_init_script, "/etc/init.d/jboss-as-standalone"
set :rails_env,         "production"
set :app_context,       "/"
set :torquebox_home,    '/opt/torquebox/current'

default_run_options[:pty] = true
ssh_options[:forward_agent] = true

after "deploy", "deploy:cleanup"

