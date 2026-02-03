#!/bin/bash

# Load RVM into the shell session
source /etc/profile.d/rvm.sh

# Pin the Ruby version used by MyS3
rvm --default use 3.1.2

# Ensure Bundler resolves gems from the project folder
export BUNDLE_GEMFILE=/home/!!ssh_username/code1/!!code_folder/Gemfile
# Provide the server-side configuration path for the app
export MY_S3_CONFIG=/home/!!ssh_username/code1/!!code_folder/config.yml

# Switch into the application directory
cd /home/!!ssh_username/code1/!!code_folder

# Launch Puma with the configured bind address, port, and thread range
exec bundle exec puma \
  -t !!puma_threads_min:!!puma_threads_max \
  -b tcp://!!bind_host:!!port \
  /home/!!ssh_username/code1/!!code_folder/config.ru
