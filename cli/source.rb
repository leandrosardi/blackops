require_relative '../lib/blackops.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
  # Check for at least one argument
  if ARGV.size == 0
    puts "Usage: source.rb <op_file> [--local] [--config=<config_file>] [--node=<node_name>] [--ssh=<ssh_credentials>] [--root] [--param1=value1] [--param2=value2] ..."
    exit 1
  end

  op_file = ARGV.shift

  # Initialize variables
  local = false
  config_file = nil
  node_name = nil
  ssh_credentials = nil
  connect_as_root = false
  parameters = {}

  # Process the rest of the arguments
  ARGV.each do |arg|
    case arg
    when '--local'
      local = true
    when '--root'
      connect_as_root = true
    when /^--config=(.+)$/
      config_file = $1
    when /^--node=(.+)$/
      node_name = $1
    when /^--ssh=(.+)$/
      ssh_credentials = $1
    when /^--(\w+)=(.*)$/
      key = $1
      value = $2
      parameters[key] = value
    else
      puts "Unknown argument: #{arg}"
      exit 1
    end
  end

  # Optionally, load a different configuration file
  if config_file
    load config_file
  end

  if local
    l.log "Running operation locally..."
    BlackOps.source_local(
      op: op_file,
      parameters: parameters,
      logger: l
    )
  else
    # Remote operation
    if node_name
      # Call source_remote with node_name
      BlackOps.source_remote(
        node_name,
        op: op_file,
        parameters: parameters,
        connect_as_root: connect_as_root,
        logger: l
      )
    elsif ssh_credentials
      # Parse ssh_credentials to create a temporary node
      # Expected format: username:password@ip:port
      match = ssh_credentials.match(/^([^:]+):([^@]+)@([\d\.]+):(\d+)$/)
      if match
        username = match[1]
        password = match[2]
        ip = match[3]
        port = match[4].to_i
binding.pry
        # Create a temporary node hash
        node_hash = {
          name: 'temp_node',
          ip: ip,
          ssh_username: username,
          ssh_password: password,
          ssh_root_password: password,
          ssh_port: port
        }
        # If connect_as_root, adjust credentials
        if connect_as_root
          node_hash[:ssh_username] = 'root'
          node_hash[:ssh_password] = password # Assuming same password
        end
        # Add the node to BlackOps nodes
        BlackOps.add_node(node_hash)

        # Call source_remote with 'temp_node' as node name
        BlackOps.source_remote(
          'temp_node',
          op: op_file,
          parameters: parameters,
          connect_as_root: connect_as_root,
          logger: l
        )
      else
        puts "Invalid SSH credentials format. Expected username:password@ip:port"
        exit 1
      end
    else
      puts "Error: You must specify either --local, --node=<node_name>, or --ssh=<ssh_credentials>"
      exit 1
    end
  end
rescue => e
  l.reset
  l.log(e.to_console.red)
end
