set_default(:server_host, "antrees.com")
set_default(:server_port, "8888")
set_default(:sub_domain, "branch")
set_default(:secret, "secret")
set_default(:env, "production")
set_default(:opentok_api_key,23037872)
set_default(:opentok_api_secret,"1ae8668cf1479d06e12f5bed1575391c452e6cde")

namespace :branch do
  desc "Generate torquebox.yml file."
  task :setup, roles: :app do
    run "mkdir -p #{shared_path}/config"
    template "torquebox.yml.erb", "#{shared_path}/config/torquebox.yml"
  end
  after "deploy:setup", "branch:setup"
  
  desc "Symlink the torquebox.yml file into latest release"
  task :symlink, roles: :app do
    run "ln -nfs #{shared_path}/config/torquebox.yml #{release_path}/config/torquebox.yml"
  end
  after "deploy:finalize_update", "branch:symlink"
  
end