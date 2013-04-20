set_default(:postgresql_host, "localhost")
set_default(:pool_size, "17")
set_default(:postgresql_user) { application }
set_default(:postgresql_password) { Capistrano::CLI.password_prompt "PostgreSQL Password: " }
set_default(:postgresql_database) { "#{application}_production" }

namespace :postgresql do
  desc "Generate the database.yml configuration file."
  task :setup, roles: :app do
    template "postgresql.yml.erb", "#{current_path}/config/database.yml"
  end
  after "deploy:setup", "postgresql:setup"

end
