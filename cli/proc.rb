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
  all = BlackOps.merged(
    name_search: node_pattern,
    logger: l
  )
  iteration = 0
  while true
    iteration += 1
    one_node_connected = false
    rows = []

    # Define the table header
    rows << [
      'Node'.bold,
      'Process'.ljust(55).bold,
      'Process'.ljust(8).bold,
      'Node'.ljust(15).bold,
    ]

    all.each do |j|
      n = j[:node]
      next unless n # Skip if no node defined

      node_name = n[:name]
      node_ip = n[:ip]

      node = nodes[node_ip]
      if n && !node && !one_node_connected && iteration > 1
        one_node_connected = true
        #l.logs "Connecting to node #{node_name.blue}... "
        begin
          node = BlackStack::Infrastructure::Node.new(n)
          node.connect
          nodes[node_ip] = node
          node_status = 'connected'.green
          #l.done
        rescue => e
          node_status = 'failed'.red
          #l.logf "Error: #{e.message}"
          next
        end
      elsif node
        node_status = 'connected'.green
      else
        node_status = 'connecting...'.yellow
      end

      # For each process defined in the node
      if n[:procs].nil? || n[:procs].empty?
        # No processes defined for this node
        rows << [
          node_name,
          '(no processes defined)',
          '-',
          node_status,
        ]
      else
        n[:procs].each do |process|
          process_status = '-'
          if node
            # Check if the process is running using a command that always exits with code 0
            escaped_process = Shellwords.escape(process)
            cmd = "ps aux | grep -v '[p]grep' | grep -v '[g]rep' | grep -F -- #{escaped_process} >/dev/null 2>&1 && echo '__PROCESS_IS_RUNNING__' || echo '__PROCESS_NOT_RUNNING__'"
            begin
              output = node.exec(cmd)
              # Parse the output to determine if the process is running
              if output.include?('__PROCESS_IS_RUNNING__') || output == ''
                process_status = 'online'.green
              elsif output.include?('__PROCESS_NOT_RUNNING__')
                process_status = 'offline'.red
              else
                process_status = 'error'.red
                #l.log "Unexpected output when checking process #{process} on node #{node_name}: #{output}"
              end
            rescue => e
              process_status = 'error'.red
              #l.log "Error checking process #{process} on node #{node_name}: #{e.message}"
            end
          else
            process_status = '-'
          end

          rows << [
            node_name,
            process,
            process_status,
            node_status,
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
