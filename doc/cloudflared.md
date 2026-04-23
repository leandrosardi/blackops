# Cloudflared

You created a cloudflared-tunnel in CloudFlare, to connect your computer via SSH from anywhere.

BlackOps provides scripts for installing and managing cloudflared.

## Installation

Use this command to install the client in your computer:

```bash
export CLOUDFLARE_TOKEN=eyJhIjoiYzQ5ZW... && \
export OPSLIB=~/code1/secret/local-ubuntu-22.04 && \
export MYSAAS_PASSWORD=2404 && \
export MYSAAS_ROOT_PASSWORD=2404 && \
saas source ./cloudflared.install.op \
  --node=localmaster \
  --root \
	--cloudflared_tunnel_token=$CLOUDFLARE_TOKEN
```

## Connecting Your Computer

```bash
ssh -o ProxyCommand="cloudflared access ssh --hostname %h" <user>@<cloudflare-domain>
```

## Stop Cloudflared

```bash
saas source ./cloudflared.stop.op \
  --node=localmaster \
  --root 
```

## Start Cloudflared

```bash
saas source ./cloudflared.start.op \
  --node=localmaster \
  --root 
```
