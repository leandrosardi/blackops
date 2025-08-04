#!/bin/bash

# Load RVM into a shell session
source /etc/profile.d/rvm.sh

# Use the default Ruby version
rvm --default use 3.1.2

# Change to the application directory
cd /home/!!ssh_username/code1/!!code_folder/extensions/monitoring/p

# Execute the Ruby application
exec ruby ./merge.rb