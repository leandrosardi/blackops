require 'net/ssh'
require 'pry'

# Replace with your server's details
HOST = 'm.massprospecting.com'      # Remote server address
USER = 'blackstack'                 # SSH username
PASSWORD = 'retert5564mbmb'         # SSH password (omit if using key authentication)

# The bash command to execute
command = <<-CMD
source /etc/profile.d/rvm.sh && \
export RUBYLIB=$HOME/code1/master && \
cd $HOME/code1/master && \
ruby launch.rb
CMD

# The bash command to execute
command = "source /etc/profile.d/rvm.sh && export RUBYLIB=$HOME/code1/master && cd /home/blackstack/code1/master && ruby launch.rb"
ssh = Net::SSH.start(HOST, USER, password: PASSWORD)
binding.pry
output = ssh.exec!(command)

Net::SSH.start(HOST, USER, password: PASSWORD) do |ssh|
binding.pry
  output = ssh.exec!(command)
  puts output

  if ssh.last_exit_status == 0
    puts "SUCCESS: Sinatra webserver started successfully."
  else
    puts "FAILURE: Sinatra webserver failed to start."
  end
end
