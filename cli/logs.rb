require_relative '../lib/blackops.rb'
load '/home/leandro/code1/blackops/BlackOpsFile'

# clean the rows array
rows = [] 

# Define the table rows
rows << [
    '#'.rjust(4).bold, 
    'Node'.bold, 
    'IP'.ljust(15).bold, 
    'Log file'.ljust(45).bold, 
    'Alerts Last Hour'.rjust(12).bold,
]

rows << [
    '1',
    'worker06',
    '55.55.55.55',
    '/home/blackstack/code1/master/allocate.log',
    '0'.green,
]

rows << [
    '2',
    'worker06',
    '55.55.55.55',
    '/home/blackstack/code1/master/dispatch.log',
    '3'.red,
]

rows << [
    '3',
    'worker06',
    '55.55.55.55',
    '/home/blackstack/code1/master/ipn.log',
    '0'.green,
]


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
    t.align_column(0, :right)    # First column: left-aligned
    t.align_column(1, :left)    # First column: left-aligned
    t.align_column(2, :left)    # First column: left-aligned
    t.align_column(3, :left)    # First column: left-aligned
    t.align_column(4, :right)    # First column: left-aligned
end

# Display the table in the terminal
system('clear')
puts table

puts ''
puts ''
puts ''
