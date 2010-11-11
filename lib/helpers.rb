require 'rubygems'
require 'rails'
require 'colored'
require 'net/http'
require 'net/ssh'

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
  remote_dir_exists?(TSRails::Constants.get(:staging_server), TSRails::Constants.get(:staging_ssh_user), "#{TSRails::Constants.get(:remote_git_dir)}/#{project_name}.git")
end

def apache_name_taken?(project_name)
  remote_dir_exists?(TSRails::Constants.get(:staging_server), TSRails::Constants.get(:staging_ssh_user), "#{TSRails::Constants.get(:remote_apache_dir)}/#{project_name}.taylored-software.com")
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

def replace_file (filename, content)
  remove_file filename
  file filename, content
end