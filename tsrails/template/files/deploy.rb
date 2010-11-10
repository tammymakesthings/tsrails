set :scm,                   :git
set :repository,            "ssh://<%= TSRails::Constants.get(:staging_server) %>/<%= TSRails::Constants.get(:remote_git_dir) %>/<%= defined_app_name.downcase %>.git"
set :branch,                "master"
set :git_enable_submodules, 1    

ssh_options[:compression] = false
ssh_options[:auth_methods] = %w{publickey password keyboard-interactive}

role :web,            "<%= TSRails::Constants.get(:staging_server) %>"
role :app,            "<%= TSRails::Constants.get(:staging_server) %>"
role :db,             "<%= TSRails::Constants.get(:staging_server) %>", :primary => true
set(:deploy_to)       { "<%= TSRails::Constants.get(:remote_apache_dir) %>/<%= defined_app_name %>.<%= TSRails::Constants.get(:test_app_domain) %>" }
set :user,            "<%= TSRails::Constants.get(:staging_ssh_user) %>"
set :use_sudo,        false
set :keep_releases,   12

namespace :bundler do
  task :install_gem do
    run("sudo /opt/ree/bin/gem install bundler --source=http://gemcutter.org")
  end

  task :bundle_new_release, :roles => :app, :except => { :no_release => true } do
    run("cd #{release_path} && /opt/ree/bin/bundle install")
  end
end

after 'deploy:setup',         'bundler:install_gem'
after 'deploy:update_code',   'bundler:bundle_new_release'
after 'deploy',               'deploy:cleanup'
