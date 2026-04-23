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
