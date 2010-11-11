############################################################################
# TAYLORED SOFTWARE RAILS APPLICATION TEMPLATE GEM V1.0                    #
############################################################################

require 'rubygems'
require 'rails'
require 'colored'
require 'net/http'
require 'net/ssh'

template_root = File.expand_path(File.join(File.dirname(__FILE__)))
source_paths << File.join(template_root, "files")

#============================================================================
# Global configuration
#============================================================================

require File.expand_path("#{File.dirname(__FILE__)}/../lib/constants.rb")
require File.expand_path("#{File.dirname(__FILE__)}/../lib/helpers.rb")

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

client_name = ask("What is the client name for this project? ")
if client_name.blank?
  msg :notice, "Blank client name specified; using \"Taylored Software\""
  client_name = "Taylored Software"
end
@client_name = client_name

printf "\n"
printf "**********************************************************************\n".magenta
printf "*".magenta
printf " And, we're off to the races!                                       ".yellow.bold
printf "*\n".magenta
printf "*                                                                    *\n".magenta
printf "* You can walk away from the computer now. No further interaction    *\n".magenta
printf "* should be required to finish generating the application.           *\n".magenta
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

copy_file "Gem.gemfile", "Gemfile", :force => true
run "bundle install"

#============================================================================
# Create the config_file initializer
#============================================================================

section "Adding initializer for app_config file"
generate "nifty:config"
remove_file "config/app_config.yml"
template "app_config.yml", "config/app_config.yml"

#============================================================================
# Set up database
#============================================================================

section "Creating databases"

rake "db:create"
rake "db:migrate"
rake "db:test:prepare"

#============================================================================
# HAML stuff
#============================================================================

section "Enabling HAML templates"
run "rails plugin install git://github.com/pjb3/rails3-generators.git"
copy_file "haml_options.rb", "config/initializers/haml_options.rb"

#============================================================================
# Install jQuery
#============================================================================

section "Changing Javascript library from script.aculo.us to jQuery"

remove_file "public/javascripts/controls.js"
remove_file "public/javascripts/dragdrop.js"
remove_file "public/javascripts/effects.js"
remove_file "public/javascripts/prototype.js"

inside "public/javascripts" do
  get_file "http://code.jquery.com/jquery-1.4.3.min.js", "jquery-1.4.3.min.js"
  get_file "https://github.com/rails/jquery-ujs/raw/master/src/rails.js", "rails.js"
end
copy_file "prefilled_input.js",  "public/javascripts/prefilled_input.js"
copy_file "jquery.rb", "config/initializers/jquery.rb"

#============================================================================
# Exception Notification stuff
#============================================================================

section "Enabling exception_notification"
run "rails plugin install https://github.com/rails/exception_notification.git"
exception_notify_config = <<-RUBY
    config.middleware.use ::ExceptionNotifier,
                          :email_prefix => "[#{defined_app_name.upcase}] ",
                          :sender_address => %w{app-errors@taylored-software.com},
                          :exception_recipients => %w{exception-notify@application.com}
RUBY
inject_into_class "config/application.rb", "Application", exception_notify_config

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

action_mailer_host "development", "#{defined_app_name}.local"
action_mailer_host "test",        "example.com"
action_mailer_host "production",  "#{defined_app_name}.taylored-software.com"

route "root :to => 'Clearance::Sessions#new'"

generators_config = <<-RUBY
    config.generators do |generate|
      generate.test_framework :rspec
      generate.fixture_replacement :factory_girl, :dir => "spec/factories"
      generate.template_engine :haml
    end
RUBY
inject_into_class "config/application.rb", "Application", generators_config
copy_file "application_helper.rb", "app/helpers/application_helper.rb", :force => true
copy_file "requires.rb", "config/initializers/requires.rb"
copy_file "noisy_attr_accessible.rb", "config/initializers/noisy_attr_accessible.rb"

copy_file "backtrace_silencers.rb", "config/initializers/backtrace_silencers.rb", :force => true

#============================================================================
# Mongrel configuration
#============================================================================

section "Setting up mongrel_cluster"
copy_file "mongrel_cluster.yml", "config/mongrel_cluster.yml"

#============================================================================
# Generate rspec and cucumber stuff
#============================================================================

section "Setting up RSpec and Cucumber"

generate "rspec:install"
generate "cucumber:install", "--rspec --capybara"

copy_file "factory_girl_steps.rb", "features/step_definitions/factory_girl_steps.rb"
template "cucumber.yml", "config/initializers/cucumber.yml"

copy_file "spec_helper.rb", "spec/spec_helper.rb", :force => true
copy_file "rcov.opts", "spec/rcov.opts", :force => true
copy_file "spec.opts", "spec/spec.opts", :force => true
copy_file "debug_steps.rb", "features/step_definitions/debug_steps.rb"

# Workaround for a bug in Cucumber's monkeypatching of Capybara
copy_file "env.rb", "features/support/env.rb", :force => true

#============================================================================
# Install tiny_mce files
#============================================================================

section "Installing files needed by tiny_mce"

rake "tiny_mce:install"
copy_file "tiny_mce.yml", "config/tiny_mce.yml", :force => true

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
generate "clearance"
generate "clearance_views"
rake "db:migrate"
rake "db:test:clone"

copy_file "clearance.rb", "config/initializers/clearance.rb", :force => true

#============================================================================
# Generate compass CSS stuff
#============================================================================

section "Generating Compass/Blueprint SASS/CSS"

run "compass init rails --using blueprint --sass-dir=app/stylesheets --css-dir=public/stylesheets/compiled/ --quiet"
run "compass compile"

#============================================================================
# Generate flashes partial
#============================================================================

section "Generating shared view partials and layouts"

empty_directory "app/views/shared"

copy_file "_flashes.html.haml", 'app/views/shared/_flashes.html.haml'
copy_file "_javascript.html.haml", 'app/views/shared/_javascript.html.haml'
template "_footer.html.haml", 'app/views/shared/_footer.html.haml'
copy_file "_sign_in_out.html.haml", 'app/views/shared/_sign_in_out.html.haml'
copy_file "_sidebar.html.haml", 'app/views/shared/_sidebar.html.haml'

remove_file 'app/views/layouts/application.html.erb'
copy_file 'application.html.haml', 'app/views/layouts/application.html.haml'

#============================================================================
# Create RVM file
#============================================================================

section "Generating rvmrc file"
copy_file "dot.rvmrc", ".rvmrc"

#============================================================================
# Set up Git
#============================================================================

section "Setting up local git repository"

git :init
git :add => "."
git :commit => "-am 'Initial commit.'"

msg :info, "Setting up remote Git repository"
run "git remote add origin ssh://#{TSRails::Constants.get(:staging_ssh_user)}@#{TSRails::Constants.get(:staging_server)}#{TSRails::Constants.get(:remote_git_dir)}/#{defined_app_name}.git"
run "ssh #{TSRails::Constants.get(:staging_server)} mkdir #{TSRails::Constants.get(:remote_git_dir)}/#{defined_app_name}.git"
run "ssh #{TSRails::Constants.get(:staging_server)} \"cd #{TSRails::Constants.get(:remote_git_dir)}/#{defined_app_name}.git ; git --bare init\""

msg :info, "Pushing code to remote Git repository"
run "git push origin master"

#============================================================================
# Set up Capistrano configuration
#============================================================================

section "Setting up Capistrano configuration for #{TSRails::Constants.get(:staging_server)}"
capify!

remove_file "config/deploy.rb"
template "deploy.rb", "config/deploy.rb"

git :commit => "-am 'Added Capistrano configuration from application template'"

#============================================================================
# Generate/Install Apache Configuration File
#============================================================================

section "Generating Apache configuration file."
  
template "apache_config.conf", "config/apache_config.conf"

git :add => "config/apache_config.conf"
git :commit => "-m 'Added apache configuration file from application template'"

#============================================================================
# Done.
#============================================================================

printf "\n"
printf "======================================================================\n".cyan.bold
printf "Done!\n".cyan.bold
printf "======================================================================\n".cyan.bold
printf "\n"

printf "To complete application setup, you will need to verify the Apache\n"
printf "configuration and install it on the server.\n"