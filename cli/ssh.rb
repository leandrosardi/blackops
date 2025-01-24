require_relative '../lib/blackops.rb'

l = BlackStack::LocalLogger.new('blackops.log')

# Initialize variables
config_file = nil
node_name = nil
connect_as_root = false

# Process command-line arguments
ARGV.each do |arg|
  if arg == '--help' || arg == '--h' || arg == '-h'
    puts 'This command opens an SSH connection with a node defined in your configuration file.'
    puts 'Usage: ops ssh [--config=<config_file>] [--root] <node name>'
    puts 'Options:'
    puts '  --config=<config_file>  Specify a custom configuration file.'
    puts '  --root                  Connect as root user.'
    puts '  --help                  Display this help message.'
    exit 0
  elsif arg == '--root'
    connect_as_root = true
  elsif arg =~ /^--config=(.+)$/
    config_file = $1
  elsif arg.start_with?('--')
    puts "Unknown option: #{arg}"
    puts 'Usage: ops ssh [--config=<config_file>] [--root] <node name>'
    exit 1
  else
    node_name = arg
  end
end

# Ensure node_name is provided
if node_name.nil?
  puts 'Error: Node name is required.'
  puts 'Usage: ops ssh [--config=<config_file>] [--root] <node name>'
  exit 1
end

begin
  # Load the configuration file
  if config_file
    l.log "Loading configuration from #{config_file}..."
    load config_file
  else
    # look for BlackOpsFile into any of the paths defined in the environment variable $OPSLIB
    BlackOps.load_blackopsfile
  end

  # Open SSH connection
  BlackOps.ssh(
    node_name.to_s,
    connect_as_root: connect_as_root,
    logger: l
  )
rescue => e
  l.reset
  l.log(e.to_console.red)
end
