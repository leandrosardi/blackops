require_relative '../lib/blackops.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
  # Check for at least one argument
  if ARGV.size == 0
    puts "Usage: source.rb <op_file> [--local] [--config=<config_file>] [--node=<node_pattern>] [--ssh=<ssh_credentials>] [--root] [--param1=value1] [--param2=value2] ..."
    exit 1
  end

  op_file = ARGV.shift

  # Initialize variables
  local = false
  config_file = nil
  node_pattern = nil
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
      node_pattern = $1
    when /^--ssh=(.+)$/
      ssh_credentials = $1
    when /^--(\w+)=(.*)$/
      key = $1
      value = $2
      parameters[key] = value
    else
      puts "Unknown argument: #{arg}"
      puts "Usage: source.rb <op_file> [--local] [--config=<config_file>] [--node=<node_pattern>] [--ssh=<ssh_credentials>] [--root] [--param1=value1] [--param2=value2] ..."
      exit 1
    end
  end

  # Load the configuration file
  if config_file
    load config_file
  else
    # Look for BlackOpsFile in any of the paths defined in the environment variable $OPSLIB
    BlackOps.load_blackopsfile
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
    if node_pattern
      # Determine if the node_pattern contains wildcards
      if node_pattern.include?('*') || node_pattern.include?('?') || node_pattern.include?('[')
        # Use File.fnmatch to match node names
        matched_nodes = BlackOps.nodes.select { |node| File.fnmatch(node_pattern, node[:name]) }.map { |node| node[:name] }

        if matched_nodes.empty?
          raise "No nodes match the pattern '#{node_pattern}'."
        end

        matched_nodes.each do |matched_node_name|
          l.log "Executing #{op_file.blue} on node #{matched_node_name.blue}..."
          BlackOps.source_remote(
            matched_node_name,
            op: op_file,
            parameters: parameters,
            connect_as_root: connect_as_root,
            logger: l
          )
        end
      else
        # No wildcard, process a single node
        # Check if the node exists
        if !BlackOps.nodes.any? { |node| node[:name] == node_pattern }
          raise "Node not found: #{node_pattern}"
        end

        l.log "Executing #{op_file.blue} on node #{node_pattern.blue}..."
        BlackOps.source_remote(
          node_pattern,
          op: op_file,
          parameters: parameters,
          connect_as_root: connect_as_root,
          logger: l
        )
      end
    elsif ssh_credentials
      # Parse ssh_credentials to create a temporary node
      # Expected format: username:password@ip:port
      match = ssh_credentials.match(/^([^:]+):([^@]+)@([\d\.]+):(\d+)$/)
      if match
        username = match[1]
        password = match[2]
        ip = match[3]
        port = match[4].to_i

        # Create a temporary node hash
        node_hash = {
          name: '__temp_node_unique_name__', # Required by add_node
          ip: ip,
          ssh_username: username,
          ssh_password: password,
          ssh_root_password: password, # Assuming same password - Just because it is mandatory by blackstack-nodes
          ssh_port: port
        }

        # Add the node to BlackOps nodes
        BlackOps.add_node(node_hash)

        # Call source_remote with '__temp_node_unique_name__' as node name
        BlackOps.source_remote(
          '__temp_node_unique_name__',
          op: op_file,
          parameters: parameters,
          connect_as_root: false,
          logger: l
        )
      else
        puts "Invalid SSH credentials format. Expected username:password@ip:port"
        exit 1
      end
    else
      puts "Error: You must specify either --local, --node=<node_pattern>, or --ssh=<ssh_credentials>"
      exit 1
    end
  end
rescue => e
  l.reset
  l.log(e.to_console.red)
end
