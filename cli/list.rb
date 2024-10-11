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

    l.logs 'Connecting to Contabo... '
    contabo = BlackOps.contabo
    if contabo.nil?
        l.skip(details: 'connection not defined')
    else
        ret = contabo.get_instances
        instances = ret['data']
        if instances.nil? || !instances.is_a?(Array)
            l.logf("error (code: #{ret['statusCode'].to_s.red} - description: #{ret['message'].to_s.red})")
            exit(1)
        else
            l.done(details: 'total: ' + instances.size.to_s.blue)
        end
    end

    # list of nodes defined in the configuration file
    l.logs "Get nodes defined in configuration... "
    nodes = BlackOps.nodes
    l.done(details: 'total: ' + nodes.size.to_s.blue)

    # Define the table rows
    rows = []
    rows << ['Name'.bold, 'IP'.bold, 'Contabo']
    
    BlackOps.nodes.each { |node|
        rows << [node[:name], node[:ip]]
    }

    # Create the table with a title
    table = Terminal::Table.new :title => "Nodes List", :rows => rows do |t|
        t.style = {
            border_x: '',  # Horizontal border character
            border_y: '',  # Vertical border character
            border_i: ''   # Intersection character
        }
    end
    
    # Display the table in the terminal
    puts table
    
rescue => e
    l.reset
    l.log(e.to_console.red)
end