############################################################################
# TAYLORED SOFTWARE RAILS APPLICATION TEMPLATE V1.0                        #
############################################################################

require 'rubygems'
require 'rails'
require 'colored'
require 'net/http'
require 'net/ssh'

#============================================================================
# Global configuration
#============================================================================

STAGING_SERVER_NAME="tsweb.taylored-software.com"
STAGING_SSH_USER="tlcravit"
REMOTE_GIT_DIR="/home/git"
REMOTE_APACHE_DIR="/var/sites"

#============================================================================
# Helper functions
#============================================================================

def get_file(http_location, file)
  uri = URI.parse(http_location)
  contents = Net::HTTP.get(uri)
  File.open(file, "w") { |f| f.write(contents) }
end

def msg(message)
  msg :info, message
end

def msg(mtype, message)
  printf "[".white.bold
  if (mtype.nil?)
    printf "message".green
  elsif (mtype.to_s.blank?)
    printf "message".green    
  elsif (mtype.to_s.downcase == "info")
    printf "info".cyan
  elsif (mtype.to_s.downcase == "warning")
    printf "warning".red
  else
    printf "message".green
  end
  printf "] ".white.bold
  printf "#{message}\n"
end

def remote_dir_exists?(hostname, username, dir_path)
  output = ""
  Net::SSH.start(hostname, username) do |ssh|
    output = ssh.exec!("ls -d #{dir_path} 2>/dev/null | wc -l").chomp.strip
  end
  output == "1"
end

def git_name_taken?(project_name)
  remote_dir_exists?(STAGING_SERVER_NAME, STAGING_SSH_USER, "#{REMOTE_GIT_DIR}/#{project_name}.git")
end

def apache_name_taken?(project_name)
  remote_dir_exists?(STAGING_SERVER_NAME, STAGING_SSH_USER, "#{REMOTE_APACHE_DIR}/#{project_name}.taylored-software.com")
end

def concat_file(source, destination)
  contents = IO.read(find_in_source_paths(source))
  append_file destination, contents
end

def replace_in_file(relative_path, find, replace)
  path = File.join(destination_root, relative_path)
  contents = IO.read(path)
  unless contents.gsub!(find, replace)
    raise "#{find.inspect} not found in #{relative_path}"
  end
  File.open(path, "w") { |file| file.write(contents) }
end

def action_mailer_host(rails_env, host)
  inject_into_file(
    "config/environments/#{rails_env}.rb",
    "\n\n  config.action_mailer.default_url_options = { :host => '#{host}' }",
    :before => "\nend"
  )
end
#============================================================================
# Startup
#============================================================================

printf "======================================================================\n".cyan.bold
printf "tayloredsw_rails.rb: Set up a Rails application template with\n".cyan.bold
printf "                     Taylored Software defaults and environment\n".cyan.bold
printf "======================================================================\n".cyan.bold
printf "\n"
printf "This script will set up a Rails application and do most of the\n".cyan
printf "application configuration for you. The script will ask several\n".cyan
printf "configuration questions at the start of the process, and then\n".cyan
printf "should run without user interaction.\n".cyan
printf "\n"

#============================================================================
# Collect needed information
#============================================================================

project_name = Dir.getwd.split(File::SEPARATOR).last

setup_git_repo = yes?("Do you want to set up a remote Git repository?")
generate_apache_conf = yes?("Do you want to generate an Apache/Passenger Config?")
if generate_apache_conf
  install_apache_conf = yes?("Do you want to attempt to install the Apache/Passenger Config?")
else
  install_apache_conf = false
end
setup_vagrant = yes?("Do you want to set up a Vagrant VM instance for this site?")

printf "\n"

if setup_git_repo || generate_apache_conf
  msg :info, "Checking if project name #{project_name} is free in Git and Apache"
  proj_name_taken = git_name_taken?(project_name) || apache_name_taken?(project_name)
  while proj_name_taken
    msg :warning, "Project name \"#{project_name}\" is already taken. Please select another."
    project_name = ask("Please select a project name: ").trim
    proj_name_taken = git_name_taken?(project_name) || apache_name_taken?(project_name)
  end
else
  msg :info, "Remote Git repo and Apache configuration both skipped, so I won't bother"
  msg :info, "checking for app name uniqueness."
end

msg :info, "Will go forward with the project name #{project_name}"

printf "\n"
printf "**********************************************************************\n".magenta
printf "You can walk away from the computer now. No further user interaction\n".magenta
printf "should be required to finish generating the application.\n".magenta
printf "**********************************************************************\n".magenta
printf "\n"

#============================================================================
# Remove unneeded files
#============================================================================

printf "\n"
msg :info, "Removing unneeded files from Rails project"

remove_file "public/index.html"
remove_file "README"
remove_file "public/favicon.ico"
remove_file "public/robots.txt"
remove_file "public/images/rails.png"

empty_directory_with_gitkeep "app/models"
empty_directory_with_gitkeep "app/views/pages"
empty_directory_with_gitkeep "db/migrate"
empty_directory_with_gitkeep "log"
empty_directory_with_gitkeep "public/images"
empty_directory_with_gitkeep "spec/support"

remove_file ".gitignore"
file ".gitignore", 
%q{# Git ignore file
.bundle
db/*.sqlite3
log/*.log
tmp/**/*
.*.swp
*~
*.tmp
.idea
.idea/*
.DS_Store
.vagrant
}

#============================================================================
# Add gems
#============================================================================

printf "\n"
msg :info, "Adding Ruby gems"
remove_file "Gemfile"
file "Gemfile",
%q{
source :rubygems

gem "rails", ">= 3.0"
gem "rack"
gem "clearance", "0.9.0.rc9"
gem "haml"
gem "high_voltage"
gem "RedCloth", :require => "redcloth"
gem "paperclip"
gem "will_paginate"
gem "formtastic"
gem "flutie"
gem "dynamic_form"
gem 'tiny_mce'

# http://blog.davidchelimsky.net/2010/07/11/rspec-rails-2-generators-and-rake-tasks/
group :development, :test, :cucumber do
  gem "rspec-rails", "~> 2.0.0"
  gem "ruby-debug"
  gem "heroku"
  gem "cucumber-rails"
  gem 'sqlite3-ruby', :require => 'sqlite3'
  gem 'nifty-generators'
end

group :test, :cucumber do
  gem "factory_girl_rails"
  gem "bourne"
  gem "capybara"
  gem "database_cleaner"
  gem "fakeweb"
  gem "nokogiri"
  gem "timecop"
  gem "treetop"
  gem "shoulda"
  gem "launchy"
end

group :production do
  gem "mysql", "2.8.1"
end  
}

msg :info, "Running \"bundle install\" - this may take a moment"
run "bundle install"

#============================================================================
# Create the config_file initializer
#============================================================================

printf "\n"
msg :info, "Adding initializer for app_config file"
inside('config') do
  file "app_config.yml", 
%q{# This is the application configuration file. Add your settings here.
# Settings in each of the environment-specific sections will override
# equivalently-named settings in the global section.

global:
  dummy_setting: 0

development:
  dummy_setting: 1

test:
  dummy_setting: 2

production:
  dummy_setting: 3  
}

  file "app_config.rb",
%q{# Initializer to load the YAML configuration file from config/app_config.yml

require 'yaml'
require 'erb'

app_config_yml =  YAML.load(ERB.new(File.read(File.join(Rails.root, "config", "app_config.yml"))).result)
APP_CONFIG = (app_config_yml["global"] || {}).merge!(app_config_yml[Rails.env] || {})).with_indifferent_access
}
end

#============================================================================
# Set up database
#============================================================================

printf "\n"
msg :info, "Creating databases"
rake "db:create"
rake "db:test:prepare"

#============================================================================
# Install jQuery
#============================================================================

printf "\n"
msg :info, "Changing Javascript library from script.aculo.us to jQuery"
remove_file "public/javascripts/controls.js"
remove_file "public/javascripts/dragdrop.js"
remove_file "public/javascripts/effects.js"
remove_file "public/javascripts/prototype.js"

inside "public/javascripts/jquery" do
  get_file "http://code.jquery.com/jquery-1.4.3.min.js", "jquery-1.4.3.min.js"
  get_file "http://github.com/rails/jquery-ujs/raw/master/src/rails.js", "rails.js" 
  file "prefilled_input.js", 
%q{
// clear inputs with starter values
new function($) {
  $.fn.prefilledInput = function() {

    var focus = function () {
      $(this).removeClass('prefilled');
      if (this.value == this.prefilledValue) {
        this.value = '';
      }
    };

    var blur = function () {
      if (this.value == '') {
        $(this).addClass('prefilled').val(this.prefilledValue);
      } else if (this.value != this.prefilledValue) {
        $(this).removeClass('prefilled');
      }
    };

    var extractPrefilledValue = function () {
      if (this.title) {
        this.prefilledValue = this.title;
        this.title = '';
      } else if (this.id) {
        this.prefilledValue = $('label[for=' + this.id + ']').hide().text();
      }
      if (this.prefilledValue) {
        this.prefilledValue = this.prefilledValue.replace(/\*$/, '');
      }
    };

    var initialize = function (index) {
      if (!this.prefilledValue) {
        this.extractPrefilledValue = extractPrefilledValue;
        this.extractPrefilledValue();
        $(this).trigger('blur');
      }
    };

    return this.filter(":input").
      focus(focus).
      blur(blur).
      each(initialize);
  };

  var clearPrefilledInputs = function () {
    var form = this.form || this;
    $(form).find("input.prefilled, textarea.prefilled").val("");
  };

  var prefilledSetup = function () {
    $('input.prefilled, textarea.prefilled').prefilledInput();
    $('form').submit(clearPrefilledInputs);
    $('input:submit, button:submit').click(clearPrefilledInputs);
  };

  $(document).ready(prefilledSetup);
  $(document).ajaxComplete(prefilledSetup);
}(jQuery);
}
end

initializer 'jquery.rb',
%q{# Switch the javascript_include_tag :defaults to
# use jQuery instead of the default prototype helpers.
# Also setup a :jquery expansion, just for good measure.
# Written by: Logan Leger, logan@loganleger.com
# http://github.com/lleger/Rails-3-jQuery

ActionView::Helpers::AssetTagHelper.register_javascript_expansion :jquery => ['jquery', 'rails', 'prefilled_input']
ActiveSupport.on_load(:action_view) do
  ActiveSupport.on_load(:after_initialize) do
    ActionView::Helpers::AssetTagHelper::register_javascript_expansion :defaults => ['jquery', 'rails', 'prefilled_input']
  end
end
}

#============================================================================
# Extra app configuration tweaks
#============================================================================

printf "\n"
msg :info, "Making minor application configuration tweaks"

extra_app_config = <<-RUBY
config.time_zone = 'Pacific Time (US & Canada)'
RUBY
inject_into_class "config/application.rb", "Application", extra_app_config

production_config = <<-RUBY
config.action_mailer.raise_delivery_errors = false
RUBY
inject_into_class "config/environments/production.rb", "config/environment.rb", production_config

action_mailer_host "development", "#{project_name}.local"
action_mailer_host "test",        "example.com"
action_mailer_host "production",  "#{project_name}.taylored-software.com"

route "root :to => 'Clearance::Sessions#new'"

#============================================================================
# Generate rspec and cucumber stuff
#============================================================================

printf "\n"
msg :info, "Setting up RSpec and Cucumber"

generators_config = <<-RUBY
    config.generators do |generate|
      generate.test_framework :rspec
      generate.fixture_replacement :factory_girl, :dir => "spec/factories"
    end
RUBY
inject_into_class "config/application.rb", "Application", generators_config

generate "rspec:install"
generate "cucumber:install", "--rspec", "--capybara"

file "features/step_definitions/factory_girl_steps.rb",
%q{
require 'factory_girl/step_definitions'
}

file "config/initializers/cucumber.yml", 
%q{<%
rerun = File.file?('rerun.txt') ? IO.read('rerun.txt') : ""
rerun_opts = rerun.to_s.strip.empty? ? "--format #{ENV['CUCUMBER_FORMAT'] || 'progress'} features" : "--format #{ENV['CUCUMBER_FORMAT'] || 'pretty'} #{rerun}"
std_opts = "--format #{ENV['CUCUMBER_FORMAT'] || 'progress'} --strict --tags ~@wip"
%>
default: <%= std_opts %> features
wip: --tags @wip:3 --wip features
rerun: <%= rerun_opts %> --format rerun --out rerun.txt --strict --tags ~@wip
}

remove_file "spec/spec_helper.rb"
file "spec/spec_helper.rb", 
%q{#
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.mock_with :mocha

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true
  
}

inject_into_file "features/support/env.rb",
                 %{Capybara.save_and_open_page_path = 'tmp'\n},
                 :before => %{Capybara.default_selector = :css}

#============================================================================
# Install tiny_mce files
#============================================================================

printf "\n"
msg :info, "Installing files needed by tiny_mce"

rake "tiny_mce:install"
remove_file "config/tiny_mce.yml"

file "config/tiny_mce.yml",
%q{#
# Here you can specify default options for TinyMCE across all controllers
#
theme: advanced
theme_advanced_resizing: true
theme_advanced_toolbar_location: "top"
theme_advanced_statusbar_location: "bottom"
theme_advanced_buttons3_add: "pastetext,pasteword,selectall"
paste_auto_cleanup_on_paste: true
relative_urls: false
remove_script_host: false
convert_urls: false
plugins:
- table
- fullscreen
- paste
}
#============================================================================
# Install flutie files
#============================================================================

printf "\n"
msg :info, "Installing Flutie files"
rake "flutie:install"

#============================================================================
# Install Formtastic stuff
#============================================================================

printf "\n"
msg :info, "Installing Formtastic files"
generate "formtastic:install"

#============================================================================
# Generate Clearance stuff
#============================================================================

printf "\n"
msg :info, "Generating Clearance files and associated model objects and mocks"

generate "clearance_features"
generate :model, "user name:string"
rake "db:migrate"
generate "clearance"
generate "clearance_views"

remove_file "config/initializers/clearance.rb"
file "config/initializers/clearance.rb",
%q{#
# Clearance configuration
#

Clearance.configure do |config|
  config.mailer_sender = 'donotreply@example.com'
end  
}

#============================================================================
# Generate partials and layouts
#============================================================================

printf "\n"
msg :info, "Generating shared view partials"

empty_directory "app/views/shared"

file 'app/views/shared/_flashes.html.erb', 
%q{<div id="flash">
  <% flash.each do |key, value| -%>
    <div id="flash_<%= key %>"><%=h value %></div>
  <% end -%>
</div>
}

file 'app/views/shared/_javascript.html.erb',
%q{<%= javascript_include_tag 'jquery', 'jquery-ui', 'prefilled_input',  :cache => true %>
<%= yield :javascript %>
}

remove_file 'app/views/layouts/application.html.erb'
file 'app/views/layouts/application.html.erb',
%q{<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-type" content="text/html; charset=utf-8" />
    <title>susptest</title>
    <%= stylesheet_link_tag :flutie, 'screen', :media => 'all', :cache => true %>
    <%= javascript_include_tag "jquery", "jquery-ui", "prefilled_input", "rails", "application", :cache => true %>
    <%= csrf_meta_tag %>
    <%= include_tiny_mce_if_needed %>
    <%= yield :head %>
  </head>
  <body class="<%= body_class %>">
    <div id="header">
      <% if signed_in? -%>
        <%= link_to "Sign out", sign_out_path, :method => :delete %>
      <% else -%>
        <%= link_to "Sign in", sign_in_path %>
      <% end -%>
    </div>
    <%= render :partial => 'shared/flashes' -%>
    <%= yield %>
    <%= render :partial => 'shared/javascript' %>
  </body>
</html>  
}


#============================================================================
# Create RVM file
#============================================================================

printf "\n"
msg :info, "Generating rvmrc file"
file ".rvmrc", %q{rvm 1.8.7-head}

#============================================================================
# Set up Vagrant to run the application
#============================================================================

if setup_vagrant
  printf "\n"
  msg :info, "Setting up Vagrant instance"
  file "Vagrantfile", 
%q{# Vagrant configuration
Vagrant::Config.run do |config|
  config.vm.box = "lucid64"
  config.vm.forward_port("web", 80, 8080)
  config.vm.forward_port("web-ssl", 443, 4443)
  config.vm.forward_port("ftp", 21, 21321)
  config.vm.forward_port("mongrel", 3000, 13000)  
  
  config.vm.provisioner = :chef_solo  
  config.chef.cookbooks_path = ["~/chef_cookbooks/tcravit_chef",
                                  "~/chef_cookbooks/opscode_chef_cookbooks",
                                  "vagrant"]
  config.chef.add_recipe("vagrant_main")
end
}

  empty_directory_with_gitkeep "vagrant"
  empty_directory_with_gitkeep "vagrant/vagrant_main"
  empty_directory_with_gitkeep "vagrant/vagrant_main/recipes"
  empty_directory_with_gitkeep "vagrant/vagrant_main/templates"
  empty_directory_with_gitkeep "vagrant/vagrant_main/templates/default"

  file "vagrant/vagrant_main/recipes/default.rb", <<-VAGRANT
############################################################################
# Vagrant provisioning scrpt
############################################################################

# Install needed compiler and system libraries
require_recipe "apt"
require_recipe "build-essential"
require_recipe "xml"
require_recipe "xslt"

# Insatll the Apache/rails/MySQL/passenger stack
require_recipe "apache2"
require_recipe "openssl"
require_recipe "mysql::server"
require_recipe "rails"
require_recipe "passenger_apache2::mod_rails"
require_recipe "sqlite"

# Install the git SCM
require_recipe "git"

# Disable the default apache site
execute "disable-default-site" do
  command "sudo a2dissite default"
  notifies :restart, resources(:service => "apache2")
end

# Update rubygems
execute "update-rubygems" do
        command "sudo /usr/bin/gem update --system"
        action :run
end

# Seed a few system-level gems; we let bundler take care of the rest
gem_package "bundler" do
        version ">1.0.0"
        action :install
end

gem_package "rails" do
  version "~> 3.0.0"
  action :install
end

# Set up the sbairbus web app
web_app "sbairbus" do
  docroot "/vagrant/public"
  server_name "#{project_name}.\#{node[:domain]}"
  server_aliases [ "#{project_name}", node[:hostname], "#{project_name}.local", "vagrantbase.local" ]
  rails_env "production"
  notifies :restart, resources(:service => "apache2")
end

execute "install-bundled-gems" do
  command "bundle install"
  cwd "/vagrant"
  action :run
end
VAGRANT

  file "vagrant/vagrant_main/templates/default/web_app.conf.erb", 
%q{
<VirtualHost *:80>
  ServerName <%= @params[:server_name] %>
  ServerAlias <% @params[:server_aliases].each do |a| %><%= "#{a}" %> <% end %>
  DocumentRoot <%= @params[:docroot] %>

  RailsBaseURI /
  RailsEnv <%= @params[:rails_env] %>
  RailsAllowModRewrite on
  PassengerMaxPoolSize <%= @node[:rails][:max_pool_size] %>

  <Directory <%= @params[:docroot] %>>
    Options FollowSymLinks
    AllowOverride None
    Order allow,deny
    Allow from all
  </Directory>

  LogLevel info
  ErrorLog <%= @node[:apache][:log_dir] %>/<%= @params[:name] %>-error.log
  CustomLog <%= @node[:apache][:log_dir] %>/<%= @params[:name] %>-access.log combined

  RewriteEngine On
  RewriteLog <%= @node[:apache][:log_dir] %>/<%= @application_name %>-rewrite.log
  RewriteLogLevel 0

  # Canonical host
  RewriteCond %{HTTP_HOST}   !^<%= @params[:server_name] %> [NC]
  RewriteCond %{HTTP_HOST}   !^$
  RewriteRule ^/(.*)$        http://<%= @params[:server_name] %>/$1 [L,R=301]

  RewriteCond %{DOCUMENT_ROOT}/system/maintenance.html -f
  RewriteCond %{SCRIPT_FILENAME} !maintenance.html
  RewriteRule ^.*$ /system/maintenance.html [L]
</VirtualHost>  
}
end

#============================================================================
# Set up Git
#============================================================================

printf "\n"
msg :info, "Setting up local git repository"
git :init
git :add => "."
git :commit => "-am 'Initial commit.'"

if setup_git_repo
  if (project_name.strip.blank?)
    msg :warning, "Project name not specified; will not set up remote git repo"
  else
    msg :info, "Setting up remote Git repository"
    run "git remote add origin ssh://#{STAGING_SSH_USER}@#{STAGING_SERVER_NAME}#{REMOTE_GIT_DIR}/#{project_name}.git"
    run "ssh #{STAGING_SERVER_NAME} mkdir #{REMOTE_GIT_DIR}/#{project_name}.git"
    run "ssh #{STAGING_SERVER_NAME} \"cd #{REMOTE_GIT_DIR}/#{project_name}.git ; git --bare init\""
    
    msg :info, "Pushing code to remote Git repository"
    run "git push origin master"
  end
else
  msg :warning, "Will not set up remote git repo"
end

#============================================================================
# Set up Capistrano configuration
#============================================================================

unless project_name.blank?
  printf "\n"
  msg :info, "Setting up Capistrano configuration for #{STAGING_SERVER_NAME}"
  capify!
  
  remove_file "config/deploy.rb"
  file "config/deploy.rb", <<-DEPLOY_RB
set :scm,                   :git
set :repository,            "ssh://#{STAGING_SERVER_NAME}#{REMOTE_GIT_DIR}/#{project_name}.git"
set :branch,                "master"
set :git_enable_submodules, 1    

ssh_options[:compression] = false
ssh_options[:auth_methods] = %w{publickey password keyboard-interactive}
ssh_options[:forward_agent] = true # Agent forwarding keys

default_run_options[:pty] = true  # Must be set for the password prompt from git to work

role :web,            "#{STAGING_SERVER_NAME}"
role :app,            "#{STAGING_SERVER_NAME}"
role :db,             "#{STAGING_SERVER_NAME}", :primary => true
set(:deploy_to)       { "#{REMOTE_APACHE_DIR}/#{project_name}.taylored-software.com" }
set :user,            "#{STAGING_SSH_USER}"
set :use_sudo,        false
set :keep_releases,   12

namespace :bundler do
  task :install_gem do
    run("sudo gem install bundler --source=http://gemcutter.org")
  end

  task :bundle_new_release, :roles => :app, :except => { :no_release => true } do
    run("cd \#\{release_path\} && bundle install")
  end
end

namespace :deploy do
  desc "Restarting mod_rails with restart.txt"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch \#\{current_path\}/tmp/restart.txt"
  end

  [:start, :stop].each do |t|
    desc "\#\{t\} task is a no-op with mod_rails"
    task t, :roles => :app do ; end
  end
end

after 'deploy:setup',         'bundler:install_gem'
after 'deploy:update_code',   'bundler:bundle_new_release'
after 'deploy',               'deploy:cleanup'
DEPLOY_RB

  git :commit => "-am 'Added Capistrano configuration from application template'"
end

#============================================================================
# Generate/Install Apache Configuration File
#============================================================================

if generate_apache_conf
  printf "\n"
  msg :info, "Generating Apache configuration file."
  file "config/apache_config.conf", <<-APACHE_CONF
<VirtualHost *:80>
  ServerName #{project_name.gsub('_', '-')}.taylored-software.com
  DocumentRoot #{REMOTE_APACHE_DIR}/#{project_name}.taylored-software.com/current/public

  ErrorLog #{REMOTE_APACHE_DIR}/#{project_name}.taylored-software.com/current/log/apache_error_log

  RailsSpawnMethod smart
  PassengerMaxRequests 5000
  PassengerStatThrottleRate 5
  RailsAppSpawnerIdleTime 0
  RailsFrameworkSpawnerIdleTime 0
  PassengerPoolIdleTime 1000

  <Directory "#{REMOTE_APACHE_DIR}/#{project_name}.taylored-software.com/current/public">
    Allow from all
    Options -MultiViews
  </Directory>
</VirtualHost>
APACHE_CONF

  git :add => "config/apache_config.conf"
  git :commit => "-m 'Added apache configuration file from application template'"
  
  if install_apache_conf
    printf "\n"
    msg :info, "Installing Apache configuration and deploying application."
    run "ssh #{STAGING_SERVER_NAME} mkdir #{REMOTE_APACHE_DIR}/#{project_name}.taylored-software.com"
    run "scp config/apache_config.conf #{STAGING_SERVER_NAME}:/tmp/#{project_name}.taylored-software.com.conf"
    run "ssh #{STAGING_SERVER_NAME} sudo cp /tmp/#{project_name}.taylored-software.com.conf /etc/apache/sites-available"
    run "ssh #{STAGING_SERVER_NAME} sudo ln -s /etc/apache/sites-available/#{project_name}.taylored-software.com.conf /etc/apache/sites-enabled/#{project_name}.taylored-software.com.conf"
    run "cap deploy:setup"
    run "cap deploy"
  end
else
  msg :warning, "Skipping generation of Apache configuration"
end

#============================================================================
# Done.
#============================================================================

printf "======================================================================\n".cyan.bold
printf "Done!\n".cyan.bold
printf "======================================================================\n".cyan.bold
printf "\n"

if install_apache_conf
  printf "To complete application setup, you will need to verify the Apache\n"
  printf "configuration and restart Apache.\n"
elsif generate_apache_conf
  printf "To complete application setup, you will need to verify the Apache\n"
  printf "configuration and install it on the server.\n"
else
  printf "I've done all I could and you should be good to go."
end