require_relative '../lib/blackops.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
  # Initialize variables
  config_file = nil
  node_name = nil
  ssh_credentials = nil
  local = false
  connect_as_root = false
  parameters = {}
  install_ops = nil

  # Process command-line arguments
  ARGV.each do |arg|
    case arg
    when '--root'
      connect_as_root = true
    when '--local'
      local = true
    when /^--config=(.+)$/
      config_file = $1
    when /^--node=(.+)$/
      node_name = $1
    when /^--ssh=(.+)$/
      ssh_credentials = $1
    when /^--install_ops=(.+)$/
      install_ops = $1.split(',')
    when /^--(\w+)=(.*)$/
      key = $1
      value = $2
      parameters[key] = value
    else
      puts "Unknown argument: #{arg}"
      puts "Usage: install.rb [--config=<config_file>] [--node=<node_name>] [--ssh=<ssh_credentials>] [--local] [--root] [--install_ops=op1,op2,...] [--param1=value1] [--param2=value2] ..."
      exit 1
    end
  end

  # Load the configuration file
  if config_file
    load config_file
  else
    # look for BlackOpsFile into any of the paths defined in the environment variable $OPSLIB
    BlackOps.load_blackopsfile
  end

  if local
    # Local execution
    if install_ops.nil?
      puts "Error: --install_ops is required when using --local."
      puts "Usage: install.rb --local --install_ops=op1,op2,... [--param1=value1] [--param2=value2] ..."
      exit 1
    end

    install_ops.each do |op_file|
      l.logs "Executing #{op_file.blue} locally..."
      BlackOps.source_local(
        op: op_file,
        parameters: parameters,
        logger: l
      )
      l.done
    end

  else
    # Remote operation
    if node_name
      # Get node from configuration
      node = BlackOps.get_node(node_name)
      if node.nil?
        raise "Node not found: #{node_name}"
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
          name: '__temp_node_unique_name__',
          ip: ip,
          ssh_username: username,
          ssh_password: password,
          ssh_root_password: password, # Assuming same password
          ssh_port: port
        }

        # Add the node to BlackOps nodes
        BlackOps.add_node(node_hash)

        # Retrieve the node
        node = BlackOps.get_node('__temp_node_unique_name__')
      else
        puts "Invalid SSH credentials format. Expected username:password@ip:port"
        exit 1
      end

      # If using --ssh, then --install_ops is required
      if install_ops.nil?
        puts "Error: --install_ops is required when using --ssh."
        puts "Usage: install.rb --ssh=<ssh_credentials> --install_ops=op1,op2,... [--param1=value1] [--param2=value2] ..."
        exit 1
      end
      node[:install] = install_ops

    else
      puts "Error: You must specify either --node=<node_name> or --ssh=<ssh_credentials> or --local"
      puts "Usage: install.rb [--config=<config_file>] [--node=<node_name>] [--ssh=<ssh_credentials>] [--local] [--root] [--install_ops=op1,op2,...] [--param1=value1] [--param2=value2] ..."
      exit 1
    end
#binding.pry
    # Merge parameters into node parameters (parameters take precedence)
    parameters.each do |k, v|
      node[k.to_sym] = v unless k.to_sym==:name && node[k.to_sym]=='__temp_node_unique_name__'
    end

    # Get the list of .op files from the node's description
    ops_list = node[:install]
    if ops_list.nil? || !ops_list.is_a?(Array) || ops_list.empty?
      raise "No .op files specified in the node's :install list."
    end
#binding.pry
    # Iterate over the list of .op files and execute them
    ops_list.each do |op_file|
      l.logs "Executing #{op_file.blue} on node #{node[:name].blue}..."
      BlackOps.source_remote(
        node[:name],
        op: op_file,
        parameters: parameters,
        connect_as_root: connect_as_root,
        logger: l
      )
      l.done
    end

  end

rescue => e
  l.reset
  l.log(e.to_console.red)
end
