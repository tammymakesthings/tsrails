require 'rubygems'
require 'yaml'
require 'erb'
require 'etc'

module TSRails
  class Constants
    def self.get(var_name)
      tsrails_config = File.expand_path(File.join("~", ".tsrails.yml"))

      unless File.exist?(tsrails_config)
        File.open(tsrails_config, 'w') do |f|
          f.printf "# Configuration for the TSRails gem - EDIT THIS!\n"
          f.printf "staging_server: staging.server.com\n"
          f.printf "staging_ssh_user: %s\n", Etc.getlogin
          f.printf "remote_git_dir: /var/git\n"
          f.printf "remote_apache_dir: /var/sites\n"
          f.printf "test_app_domain: example.com\n"
        end
        puts "A tsrails configuration file was generated as "
        puts "   #{tsrails_config}"
        puts "Please edit it as appropriate and rerun the tsrails command."
        exit 1
      end
      tsrails_config = YAML.load_file(tsrails_config)
      tsrails_config[var_name.to_s]
    end
  end
end