############################################################################
# TAYLORED SOFTWARE RAILS APPLICATION TEMPLATE GEM V2.0                    #
############################################################################

require 'rubygems'
require 'rails'
require 'colored'
require 'net/http'
require 'net/ssh'

template_root = File.expand_path(File.join(File.dirname(__FILE__)))
source_paths << File.join(template_root, "files")
ruby_version = "1.9.3"

#============================================================================
# Global configuration
#============================================================================

require File.expand_path(File.join(template_root, "..", "lib", "constants.rb"))
require File.expand_path(File.join(template_root, "..", "lib", "helpers.rb"))

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

client_name = ask_with_default("What is the client name for this project? ", @app_name)
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
# RVM
#============================================================================

section "Making an RVM gemset for #{@app_name}"
run "rvm #{ruby_version}"
run "rvm gemset create #{@app_name}"
run "rvm gemset use #{@app_name}"
run "echo \"rvm ruby-#{ruby_version}@#{@app_name}\" > .rvmrc"

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
empty_directory_with_gitkeep "spec/support"
empty_directory_with_gitkeep "spec/routing"
empty_directory_with_gitkeep "spec/models"
empty_directory_with_gitkeep "spec/requests"

#============================================================================
# Add gems
#============================================================================

section "Adding Ruby gems (this may take a while)"

copy_file "Gem.gemfile", "Gemfile", :force => true
run "bundle install --binstubs"

#============================================================================
# Set up database
#============================================================================

section "Creating databases"

run "bundle exec rake db:create"
run "bundle exec rake db:migrate"
run "bundle exec rake db:test:clone"

#============================================================================
# HAML stuff
#============================================================================

section "Enabling HAML templates"
copy_file "haml_options.rb", "config/initializers/haml_options.rb"

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

action_mailer_host "development", "#{@app_name}.local"
action_mailer_host "test",        "example.com"
action_mailer_host "production",  "#{@app_name}.taylored-software.com"

route "root :to => 'Clearance::Sessions#new'"

generators_config = <<-RUBY
  config.generators do |g|
    g.test_framework :rspec, :views => false, :fixture => true
    g.fixture_replacement :factory_girl, :dir => 'spec/factories'
    g.form_builder :simple_form
    g.template_engine :haml
  end
RUBY

inject_into_class "config/application.rb", "Application", generators_config

copy_file "application_helper.rb", "app/helpers/application_helper.rb", :force => true
copy_file "requires.rb", "config/initializers/requires.rb"
copy_file "noisy_attr_accessible.rb", "config/initializers/noisy_attr_accessible.rb"
copy_file "backtrace_silencers.rb", "config/initializers/backtrace_silencers.rb", :force => true

#============================================================================
# Generate rspec and cucumber stuff
#============================================================================

section "Setting up RSpec/Spork/Guard"

generate "rspec:install"

copy_file "spec_helper.rb", "spec/spec_helper.rb", :force => true
copy_file "rcov.opts", "spec/rcov.opts", :force => true
copy_file "spec.opts", "spec/spec.opts", :force => true
copy_file "mailer_macros.rb", "spec/support/mailer_macros.rb", force: true
copy_file "Guardfile", "Guardfile", force: true


#============================================================================
# Install Formtastic stuff
#============================================================================

section "Installing SimpleForm files"
generate "simple_form:install"

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
# Set up Git
#============================================================================

section "Setting up local git repository"

git :init
git :add => "."
git :commit => "-am 'Initial commit.'"

#msg :info, "Setting up remote Git repository"
#run "git remote add origin ssh://#{TSRails::Constants.get(:staging_ssh_user)}@#{TSRails::Constants.get(:staging_server)}#{TSRails::Constants.get(:remote_git_dir)}/#{@app_name}.git"
#run "ssh #{TSRails::Constants.get(:staging_server)} mkdir #{TSRails::Constants.get(:remote_git_dir)}/#{@app_name}.git"
#run "ssh #{TSRails::Constants.get(:staging_server)} \"cd #{TSRails::Constants.get(:remote_git_dir)}/#{@app_name}.git ; git --bare init\""

#msg :info, "Pushing code to remote Git repository"
#run "git push origin master"

#============================================================================
# Set up Consular Termfile
#============================================================================

section "Setting up Termfile for Consular"
template "Termfile", "Termfile"

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
