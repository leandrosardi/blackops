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

CONFIG_PATH="$MY_S3_CONFIG"

config_value() {
  local key="$1"
  local fallback="$2"
  CONFIG_PATH="$CONFIG_PATH" CONFIG_KEY="$key" CONFIG_FALLBACK="$fallback" ruby -ryaml <<'RUBY'
require 'yaml'
path = ENV.fetch('CONFIG_PATH')
config = (YAML.safe_load(File.read(path), permitted_classes: [], aliases: false) || {})
key = ENV.fetch('CONFIG_KEY')
value = config[key] || config[key.to_sym]
fallback = ENV.fetch('CONFIG_FALLBACK')
print(value.nil? || value.to_s.strip.empty? ? fallback : value)
RUBY
}

BIND_HOST=$(config_value "bind_host" "0.0.0.0")
PORT=$(config_value "port" "4567")
THREADS_MIN=$(config_value "puma_threads_min" "4")
THREADS_MAX=$(config_value "puma_threads_max" "16")

# Launch Puma with the configured bind address, port, and thread range
exec bundle exec puma \
  -t "${THREADS_MIN}:${THREADS_MAX}" \
  -b "tcp://${BIND_HOST}:${PORT}" \
  /home/!!ssh_username/code1/!!code_folder/config.ru
