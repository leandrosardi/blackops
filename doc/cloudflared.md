# Cloudflared

This guide explains how to use BlackOps scripts to install and manage a Cloudflare Tunnel connector for SSH access.

With this setup, you can securely connect to your computer over SSH from anywhere.

## Installation

Run the following command to install and configure `cloudflared` on your machine:

```bash
export CLOUDFLARE_TOKEN=eyJhIjoiYzQ5ZW... && \
saas source ./cloudflared.install.op \
  --local \
  --cloudflared_tunnel_token=$CLOUDFLARE_TOKEN
```

## SSH Connection

Use this command to connect through Cloudflare Tunnel:

```bash
ssh -o ProxyCommand="cloudflared access ssh --hostname %h" <user>@<cloudflare-domain>
```

Example:

```bash
ssh -o ProxyCommand="cloudflared access ssh --hostname %h" leandro@dev2.connectionsphere.com
```

## Stop Service

Stop the `cloudflared` service:

```bash
saas source ./cloudflared.stop.op --local
```

## Start Service

Start the `cloudflared` service:

```bash
saas source ./cloudflared.start.op --local
```

## Removing Cloudflared

```bash
#!/bin/bash

set -e

echo "Stopping and disabling cloudflared service (if exists)..."
sudo systemctl stop cloudflared 2>/dev/null || true
sudo systemctl disable cloudflared 2>/dev/null || true

echo "Removing systemd service file..."
sudo rm -f /etc/systemd/system/cloudflared.service
sudo systemctl daemon-reload

echo "Removing cloudflared binary (common locations)..."
sudo rm -f /usr/local/bin/cloudflared
sudo rm -f /usr/bin/cloudflared

echo "Removing package (if installed via apt)..."
sudo apt remove -y cloudflared 2>/dev/null || true

echo "Removing config directories..."
rm -rf ~/.cloudflared
sudo rm -rf /etc/cloudflared

echo "Done. Verifying..."

if command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared עדיין exists in PATH"
else
  echo "cloudflared successfully removed"
fi

systemctl status cloudflared 2>/dev/null || echo "Service not found"

echo "Cleanup complete."
```