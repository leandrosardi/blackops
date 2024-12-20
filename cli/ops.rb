#!/usr/bin/env ruby

# This script has been generated with GPT-4o, using the following pronpt:
=begin
From this requirement below, please write a ruby script:

The `ops` command simply receives the name of a Ruby **script** that you want to execute.

```
ops <ruby script filename>
```

The `ops` command will look for such a script into the folder specified in the environment variable `$SAASLIB`. 

If the script your call receives parameters, then you can add them.

```
ops <ruby script filename> <list of command line parameters>
```

E.g.: The command below with shown the installed version My.SaaS:

```
ops version
```
=end

# Check if the $SAASLIB environment variable is set
saaslib_path = ENV['SAASLIB']

if saaslib_path.nil? || saaslib_path.empty?
  puts "Error: SAASLIB environment variable is not set."
  exit 1
end

# Check if a script name is provided
if ARGV.empty?
  puts "Usage: ops <ruby script filename> [arguments...]"
  exit 1
end

script_name = ARGV.shift # Get the script name
script_path = File.join(saaslib_path, script_name) + '.rb'

# Check if the script exists in the SAASLIB directory
unless File.exist?(script_path)
  puts "Error: Script '#{script_name}' not found in SAASLIB directory."
  exit 1
end

# Execute the script with the remaining arguments
exec("ruby", script_path, *ARGV)
