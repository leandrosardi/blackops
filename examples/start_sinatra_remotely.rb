require 'net/ssh'

# Replace with your server's details
HOST = 'm.massprospecting.com'      # Remote server address
USER = 'blackstack'                 # SSH username
PASSWORD = 'retert5564mbmb'         # SSH password (omit if using key authentication)

# The bash command to execute
command = <<-CMD
export RUBYLIB=$HOME/code1/master && \
cd $HOME/code1/master && \
source /etc/profile.d/rvm.sh && \
ruby $HOME/code1/master/launch.rb
CMD

success = false

# pass verbose: :debug to see the debug output in detail
Net::SSH.start(HOST, USER, password: PASSWORD) do |ssh|
  ssh.exec!(command) do |channel, stream, data|
    puts "serer-logs: #{data}"
    # puts "stream: #{stream}"
    # puts "channel: #{channel}"

    if data.include?("Web server started successfully")
      channel.close
      success = true
    end
  end

  if success
    puts "SUCCESS: Sinatra webserver started successfully."
  else
    puts "ERROR: Sinatra webserver failed to start."
  end
end