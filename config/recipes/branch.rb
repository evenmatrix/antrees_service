set_default(:server_host, "localhost")
set_default(:server_port, "8888")
set_default(:sub_domain, "branch")
set_default(:secret, "secret")
set_default(:env, "production")
set_default(:OPENTOK_API_KEY,23037872)
set_default(:OPENTOK_API_SECRET,"1ae8668cf1479d06e12f5bed1575391c452e6cde")

namespace :branch do
  desc "Generate torquebox.yml file."
  task :setup, roles: :app do
    template "torquebox.yml.erb", "#{current_path}/config/torquebox.yml"
  end
  after "deploy:setup", "branch:setup"
end