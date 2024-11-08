require_relative '../lib/blackops.rb'
load '/home/leandro/code1/secret/BlackOpsFile'

l = BlackStack::LocalLogger.new('blackops.log')

# Check if a script name is provided
if ARGV.empty? || ARGV[0] == '--help' || ARGV[0] == '--h' || ARGV[0] == '-h'
    puts 'This command opens an SSH connection with a node defined in your configuration file.'
    puts "Usage: ops ssh <node name>"
    exit 1
end

node_name = ARGV.shift # Get the name of the node to connect

begin
    BlackOps.ssh( node_name.to_sym,
        connect_as_root: false,
        logger: l
    )
rescue => e
    l.reset
    l.log(e.to_console.red)
end