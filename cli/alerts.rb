require_relative '../lib/blackops.rb'
require 'terminal-table'
require 'colorize'

l = BlackStack::LocalLogger.new('blackops.log')

begin
  config_file = nil
  node_pattern = nil
  interval = 1
  nodes = {} # Hash to store node instances with SSH connections

  # Process command-line arguments
  ARGV.each do |arg|
    case arg
    when /^--config=(.+)$/
      config_file = $1
    when /^--node=(.+)$/
      node_pattern = $1
    when /^--interval=(.+)$/
      interval = $1.to_i
    else
      puts "Unknown argument: #{arg}"
      puts "Usage: proc.rb [--config=<config_file>] [--node=<node_pattern>] [--interval=<poll seconds>]"
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

  l.logs "Pattern: "
  if node_pattern
    l.logf node_pattern.blue
  else
    l.logf '(all)'.blue
  end

  # Get the list of nodes, possibly merged with instances if needed
  all = BlackOps.nodes
  iteration = 0
  while true
    iteration += 1
    one_node_connected = false
    rows = []

    # Define the table header
    rows << [
      'Node'.bold,
      'Alert'.ljust(55).bold,
      'Passed?'.ljust(8).bold,
    ]

    all.each do |n|
      node_name = n[:name]
      node_ip = n[:ip]

      # For each process defined in the node
      if n[:alerts].nil? || n[:alerts].empty?
        # No processes defined for this node
        rows << [
          node_name,
          '(no alerts defined)',
          '-',
        ]
      else
        n[:alerts].keys.each do |k|
          b = n[:alerts][k].call(n)
          rows << [
            node_name,
            k,
            b ? 'yes'.green : 'no'.red,
          ]
        end
      end
    end

    # Create and display the table
    table = Terminal::Table.new(rows: rows) do |t|
      t.style = {
        border_x: '',  # Horizontal border character
        border_y: '',  # Vertical border character
        border_i: ''   # Intersection character
      }

      # Align columns
      t.align_column(0, :left)    # Node
      t.align_column(1, :left)    # Process
      t.align_column(2, :left)    # Process Status
      t.align_column(3, :left)    # Node Status
    end

    system('clear')
    puts table
    sleep(interval) if !one_node_connected
  end

rescue => e
  l.reset
  l.log(e.to_console.red)
end
