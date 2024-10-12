require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('blackops.log')

# Check if a script name is provided
if ARGV[0] == '--help' || ARGV[0] == '--h' || ARGV[0] == '-h'
    puts "This command merges the list of nodes in the configuration file with the nodes configured in Contabo, and show a list of nodes with infrastructure information."
    puts "Usage: ops ssh <optional: pattern filter nodes>"
    exit 1
end
  
x = ARGV.shift # Get pattern

begin
    l.logs "Pattern: " 
    if x
        l.logf x.blue
    else
        l.logf '(all)'.blue
    end

    all = BlackOps.merged(
        name_search: x,
        logger: l
    )
    
    while (true)
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
            
            branch = j[:node] ? j[:node][:git_branch] : '-'
            ram = j[:node] ? 'connecting...'.yellow : '-'

            rows << [
                j[:node].nil? ? '-' : j[:node][:name], 
                ip, 
                j[:instance].nil? ? '-' : j[:instance]['name'], 
                j[:instance].nil? ? '-' : j[:instance]['cancelDate'],
                branch,
                '', # ram
                '', # cpu
                '', # disk
                '', # alerts
                'connecting...'.yellow,
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
        sleep(10)
    end # while (true)

rescue => e
    l.reset
    l.log(e.to_console.red)
end