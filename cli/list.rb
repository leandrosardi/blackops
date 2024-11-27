require_relative '../lib/blackops.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
    config_file = nil
    node_pattern = nil
    nodes = {} # blackstack-node instances with ssh connection

    # Process the rest of the arguments
    ARGV.each do |arg|
        case arg
        when /^--config=(.+)$/
            config_file = $1
        when /^--node=(.+)$/
            node_pattern = $1
        else
            puts "Unknown argument: #{arg}"
            puts "Usage: list.rb [--config=<config_file>] [--node=<node_pattern>]"
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

    all = BlackOps.merged(
        name_search: node_pattern,
        logger: l
    )
    
    # ssh connections to each IP
    iteration = 0 
    while (true)
        # don't try to connect anything at the first iteration
        iteration += 1
        # raise this flag on when one node has been connected
        one_node_connected = false

        # clean the rows array
        rows = [] 

        # Define the table rows
        rows << [
            'Name'.bold, 
            'IP'.ljust(15).bold, 
            'Contabo'.ljust(12).bold, 
            'Expire'.rjust(12).bold,
            'Braanch'.ljust(10).bold,
            'RAM'.rjust(10).bold,
            'CPU'.rjust(10).bold,
            'Disk'.rjust(10).bold,
            'Alerts'.rjust(10).bold,
            'Status'.ljust(10).bold, 
        ]

        all.each { |j|
            ip = j[:node][:ip] if j[:node]
            ip = j[:instance].dig('ipConfig', 'v4', 'ip') if ip.nil? && j[:instance]

            node = nodes[ip]
            if j[:node] && !node && !one_node_connected && iteration>1
                one_node_connected = true
                n = j[:node]
                node = BlackStack::Infrastructure::Node.new(n)          
                ssh = node.connect
                nodes[ip] = node
            end

            branch = j[:node] ? j[:node][:git_branch] : '-'
            #ram = j[:node] ? 'connecting...'.yellow : '-'

            status = 'unknown'.red
            if j[:node]
                if node
                    status = 'online'.green
                else
                    status = 'connecting...'.yellow
                end
            end # if j[:node]

            if node
                # get usage
                usage = node.usage

                # calculate usage rates
                cpu_usage_percent = usage[:cpu_load_average].chomp.gsub('%', '').to_f
                cpu = format('%.2f%%', cpu_usage_percent)

                used_ram_mb = usage[:mb_total_memory] - usage[:mb_free_memory]
                ram_usage_percent = (used_ram_mb / usage[:mb_total_memory].to_f) * 100
                ram = format('%.2f%%', ram_usage_percent)

                used_disk_mb = usage[:mb_total_disk] - usage[:mb_free_disk]
                disk_usage_percent = (used_disk_mb / usage[:mb_total_disk].to_f) * 100
                dsk = format('%.2f%%', disk_usage_percent)

                # apply colorization
                cpu_threshold = j[:node][:cpu_threshold]
                ram_threshold = j[:node][:ram_threshold]
                disk_threshold = j[:node][:disk_threshold]

                cpu = cpu_usage_percent >= cpu_threshold ? cpu.red : cpu.green if cpu_threshold
                ram = ram_usage_percent >= ram_threshold ? ram.red : ram.green if ram_threshold
                dsk = disk_usage_percent >= disk_threshold ? dsk.red : dsk.green if disk_threshold

                # custom alerts
                alerts = '0'.green
            else
                ram = "-"
                cpu = "-"
                dsk = "-"
                alerts = "-"
            end

            rows << [
                j[:node].nil? ? '-' : j[:node][:name], 
                ip, 
                j[:instance].nil? ? '-' : j[:instance]['name'], 
                j[:instance].nil? ? '-' : j[:instance]['cancelDate'],
                branch,
                ram,
                cpu,
                dsk,
                alerts,
                status,
            ]
        }

        # Create the table with a title
        table = Terminal::Table.new(:rows => rows) do |t|
            t.style = {
                border_x: '',  # Horizontal border character
                border_y: '',  # Vertical border character
                border_i: ''   # Intersection character
            }

            # Set column widths (e.g., 20, 15, 25, 15, 10, 20)
            #t.column_widths = [20, 15, 25, 15, 10, 20]

            # Align columns: 0 for left, 1 for center, 2 for right
            t.align_column(0, :left)    # First column: left-aligned
            t.align_column(1, :left)  # Second column: center-aligned
            t.align_column(2, :left)    # Third column: left-aligned
            t.align_column(3, :right)   # Fourth column: right-aligned
            t.align_column(4, :left)  # Fifth column: center-aligned
            t.align_column(5, :right)   # Sixth column: right-aligned
            t.align_column(6, :right)
            t.align_column(7, :right)
            t.align_column(8, :right)
            t.align_column(9, :left)
        end
        
        # Display the table in the terminal
        system('clear')
        puts table
        sleep(10) if !one_node_connected
    end # while (true)

rescue => e
    l.reset
    l.log(e.to_console.red)
end