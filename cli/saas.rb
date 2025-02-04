#!/usr/bin/env ruby
# File: saas.rb
# Usage: ruby saas.rb [operation] [options...]
# Example: ruby saas.rb deploy --node=foo --root

require 'pathname'

# Extract the operation name (e.g. "deploy")
operation = ARGV.shift
if !operation
  puts "Usage: saas.rb [operation] [options...]"
  puts "       e.g. ruby saas.rb deploy --node=foo --root"
  exit 1
end

# Build the path to the target operation script, e.g. "deploy.rb"
# Assuming it's in the same directory as saas.rb
script_dir  = Pathname.new(__FILE__).realpath.dirname
script_file = script_dir.join("#{operation}.rb")

unless script_file.exist?
  puts "Error: Unknown operation '#{operation}'"
  puts "Available operations are likely: alerts, deploy, install, list, migrations, proc, source, ssh, start, stop, version."
  exit 1
end

# Now delegate to that script by spinning up a new Ruby process
# The remaining command-line arguments (ARGV) are passed through unmodified.
load script_file
