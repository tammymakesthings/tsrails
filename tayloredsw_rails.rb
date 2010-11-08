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

def section(descr)
  printf "\n"
  msg :info, descr
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

client_name = ask("What is the client name for this project? ")
if client_name.blank?
  msg :notice, "Blank client name specified; using \"Taylored Software\""
  client_name = "Taylored Software"
end

setup_git_repo = yes?("Do you want to set up a remote Git repository? ")
generate_apache_conf = yes?("Do you want to generate an Apache/Passenger Config? ")
if generate_apache_conf
  install_apache_conf = yes?("Do you want to attempt to install the Apache/Passenger Config? ")
else
  install_apache_conf = false
end
printf "\n"

if setup_git_repo || generate_apache_conf
  msg :info, "Checking if project name #{project_name} is free in Git and Apache"
  proj_name_taken = git_name_taken?(project_name) || apache_name_taken?(project_name)
  while proj_name_taken
    msg :warning, "Project name \"#{project_name}\" is already taken. Please select another."
    project_name = ask("Please select a project name: ")
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

#============================================================================
# Remove unneeded files
#============================================================================

section "Removing unneeded files from Rails project"

remove_file "public/index.html"
remove_file "README"
remove_file "public/favicon.ico"
remove_file "public/robots.txt"
remove_file "public/images/rails.png"

empty_directory_with_gitkeep "app/models"
empty_directory_with_gitkeep "db/migrate"
empty_directory_with_gitkeep "log"
empty_directory_with_gitkeep "public/images"
empty_directory_with_gitkeep "spec/support"

#============================================================================
# Add gems
#============================================================================

section "Adding Ruby gems (this may take a while)"

remove_file "Gemfile"
file "Gemfile",
%q{
source :rubygems

gem "rails", ">= 3.0"
gem "rack"
gem "clearance", "0.9.0.rc9"
gem "haml"
gem "haml-rails"
gem "hpricot"
gem "high_voltage"
gem "RedCloth", :require => "redcloth"
gem "paperclip"
gem "will_paginate"
gem "formtastic"
gem "flutie"
gem "dynamic_form"
gem 'tiny_mce'
gem "capistrano"
gem "error_messages_for"
gem "nokogiri"
gem "yaml_config_file", "~> 0.2.3"

group :development do
  gem "mongrel"
  gem "rails-footnotes"
end

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
  gem "factory_girl_rails", "~> 1.0"
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
  gem "mongrel"
  gem "mongrel_cluster"
end  
}
run "bundle install"

#============================================================================
# Set up Exception Notification E-mailer
#============================================================================

section "Installing and configuring exception_notification plugin"

run "git clone git://github.com/rails/exception_notification vendor/plugins"
exception_notify_config <<-NOTIFY
config.middleware.use ExceptionNotifier,
  :email_prefix => "[#{project_name}] ",
  :sender_address => %{"notifier" <notifier@taylored-software.com>},
  :exception_recipients => %w{tcravit@taylored-software.com}
NOTIFY

inject_into_class "config/application.rb", "Application", exception_notify_config

#============================================================================
# Create the config_file initializer
#============================================================================

section "Adding initializer for app_config file"

inside('config') do
  file "app_config.yml", <<-EOF
# This is the application configuration file. Add your settings here.
# Settings in each of the environment-specific sections will override
# equivalently-named settings in the global section.

global:
  client_name: #{client_name}
  project_name: #{project_name}

development:
  dummy_setting: 1

test:
  dummy_setting: 2

production:
  dummy_setting: 3  
EOF

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

section "Creating databases"

rake "db:create"
rake "db:test:prepare"

#============================================================================
# Install jQuery
#============================================================================

section "Changing Javascript library from script.aculo.us to jQuery"

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

section "Making application configuration tweaks"

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

generators_config = <<-RUBY
    config.generators do |generate|
      generate.test_framework :rspec
      generate.fixture_replacement :factory_girl, :dir => "spec/factories"
      generate.template_engine :haml
    end
RUBY
inject_into_class "config/application.rb", "Application", generators_config

remove "app/helpers/application_helper.rb"
file "app/helpers/application_helper.rb", 
%q{module ApplicationHelper
  def body_class
    qualified_controller_name = controller.controller_path.gsub('/','-')
    "#{qualified_controller_name} #{qualified_controller_name}-#{controller.action_name}"
  end
end}

file "config/initializers/requires.rb", 
%q{
  Dir[File.join(RAILS_ROOT, 'lib', 'extensions', '*.rb')].each do |f|
    require f
  end

  Dir[File.join(RAILS_ROOT, 'lib', '*.rb')].each do |f|
    require f
  end  
}

file "config/initializers/noisy_attr_accessible.rb",
%q{ActiveRecord::Base.class_eval do
  def log_protected_attribute_removal(*attributes)
    raise "Can't mass-assign these protected attributes: #{attributes.join(', ')}"
  end
end
}

remove "config/initializers/backtrace_silencers.rb"
file "config/initializers/backtrace_silencers.rb",
%q{SHOULDA_NOISE      = %w( shoulda )
FACTORY_GIRL_NOISE = %w( factory_girl )
THOUGHTBOT_NOISE   = SHOULDA_NOISE + FACTORY_GIRL_NOISE

Rails.backtrace_cleaner.add_silencer do |line| 
  THOUGHTBOT_NOISE.any? { |dir| line.include?(dir) }
end

# When debugging, uncomment the next line.
# Rails.backtrace_cleaner.remove_silencers!
}


#============================================================================
# Mongrel configuration
#============================================================================

section "Setting up mongrel_cluster"
file "config/mongrel_cluster.yml", 
%q{--- 
# cwd: /home/CHANGEME/apps/CHANGEME/current
# port: "3030"
environment: production
address: 127.0.0.1
pid_file: log/mongrel.pid
servers: 3
}


#============================================================================
# Generate rspec and cucumber stuff
#============================================================================

section "Setting up RSpec and Cucumber"

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

remove "spec/rcov.opts"
file "spec/rcov.opts", 
%q{--exclude "spec/*,gems/*"
--rails
}

remove "spec/spec.opts"
file "spec/spec.opts", 
%q{--colour
--format progress
--loadby mtime
--reverse
}

file "features/step_definitions/debug_steps.rb", 
%q{#
When 'I save and open the page' do
  save_and_open_page
end

Then /^show me the sent emails?$/ do
  pretty_emails = ActionMailer::Base.deliveries.map do |mail|
    <<-OUT
To: #{mail.to.inspect}
From: #{mail.from.inspect}
Subject: #{mail.subject}
Body:
#{mail.body}
.
      OUT
    end
    puts pretty_emails.join("\n")
  end    
}

#============================================================================
# Install tiny_mce files
#============================================================================

section "Installing files needed by tiny_mce"

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

section "Installing Flutie files"
rake "flutie:install"

#============================================================================
# Install Formtastic stuff
#============================================================================

section "Installing Formtastic files"
generate "formtastic:install"

#============================================================================
# Generate Clearance stuff
#============================================================================

section "Generating Clearance files and associated model objects and mocks"

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
# Generate flashes partial
#============================================================================

section "Generating shared view partials"

empty_directory "app/views/shared"

file 'app/views/shared/_flashes.html.haml', 
%q{#flashes
  - if flash[:notice]
    #flash_notice
      %p= flash[:notice]
  - if flash[:error]
    #flash_error
      %p= flash[:error]
  - if flash[:info]
    #flash_info
      %p= flash[:info]
}

file 'app/views/shared/_javascript.html.haml', 
%q{= javascript_include_tag 'jquery', 'jquery-ui', 'prefilled_input',  :cache => true
= yield :javascript
}

file 'app/views/shared/_footer.html.haml',
%q{#footer
  Copyright &copy;
  = Time.now.year
  , 
  = APP_CONFIG[:client_name]
  . All rights reserved. Web development by
  %a{:href => "http://www.taylored-software.com", :target => "_blank"}
    Taylored Software
  .
}

file 'app/views/shared/_sign_in_out.html.haml',
%q{- if signed_in?
  = link_to "Sign out", sign_out_path, :method => :delete
- else
  = link_to "Sign in", sign_in_path
}

remove_file 'app/views/layouts/application.html.erb'
file 'app/views/layouts/application.html.haml',
%q{!!!
%html
  %head
    %meta{"http-equiv" => "Content-type", :content => "text/html; charset=utf-8"}
    %title= Page Title
    = stylesheet_link_tag :flutie, 'screen', :media => 'all', :cache => true
    = javascript_include_tag javascript_include_tag "jquery", "jquery-ui", "prefilled_input", "rails", "application", :cache => true
    = csrf_meta_tag
    = include_tiny_mce_if_needed
    = yield :head
  %body
    #container
      #header
        = render :partial => 'shared/sign_in_out'
      #content
        = render :partial => 'shared/flashes'
        = yield
        = render :partial => 'shared/javascript'
      #footer
        = render :partial => 'shared/footer'
}


#============================================================================
# Create RVM file
#============================================================================

section "Generating rvmrc file"

file ".rvmrc", %q{rvm 1.8.7-head}

#============================================================================
# Set up Git
#============================================================================

section "Setting up local git repository"

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

  section "Setting up Capistrano configuration for #{STAGING_SERVER_NAME}"
  capify!
  
  remove_file "config/deploy.rb"
  file "config/deploy.rb", <<-DEPLOY_RB
set :scm,                   :git
set :repository,            "ssh://#{STAGING_SERVER_NAME}#{REMOTE_GIT_DIR}/#{project_name}.git"
set :branch,                "master"
set :git_enable_submodules, 1    

ssh_options[:compression] = false
ssh_options[:auth_methods] = %w{publickey password keyboard-interactive}

role :web,            "#{STAGING_SERVER_NAME}"
role :app,            "#{STAGING_SERVER_NAME}"
role :db,             "#{STAGING_SERVER_NAME}", :primary => true
set(:deploy_to)       { "#{REMOTE_APACHE_DIR}/#{project_name}.taylored-software.com" }
set :user,            "#{STAGING_SSH_USER}"
set :use_sudo,        false
set :keep_releases,   12

namespace :bundler do
  task :install_gem do
    run("sudo /opt/ree/bin/gem install bundler --source=http://gemcutter.org")
  end

  task :bundle_new_release, :roles => :app, :except => { :no_release => true } do
    run("cd \#\{release_path\} && /opt/ree/bin/bundle install")
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
  section "Generating Apache configuration file."
  
  file "config/apache_config.conf", <<-APACHE_CONF
<VirtualHost *:80>
  ServerName #{project_name}.taylored-software.com
  DocumentRoot #{REMOTE_APACHE_DIR}/#{project_name}.taylored-software.com/current/public

  CustomLog #{REMOTE_APACHE_DIR}/#{project_name}.taylored-software.com/current/log/apache_access_log "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"" 
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

printf "\n"
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