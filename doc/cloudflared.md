# Cloudflared

This guide documents `cloudflared.install.op`, `cloudflared.start.op`, and `cloudflared.stop.op` to run a Cloudflare Tunnel connector on a local machine using `saas source`.

The workflow is aligned with the Zero Trust dashboard flow shown in your screenshots:

1. Create a tunnel (`Cloudflared`) in Cloudflare.
2. Copy the token from **Install and run connectors**.
3. Run `cloudflared.install.op` on the local node.
4. Configure SSH routes in **Published application routes**.

## Prerequisites

1. You must have at least one DNS zone (domain) in your Cloudflare account.
2. You need Zero Trust access with Tunnel and DNS permissions.
3. The local server must have SSH listening on port 22.

Important notes:

1. You cannot publish hostnames under `*.cloudflare.com` unless that zone belongs to your account.
2. Typical setup: use your own domain (example: `connectionsphere.com`) and hostnames like `dev2.connectionsphere.com`.
3. If the Domain selector shows `No valid options`, your current account has no available DNS zone or your user permissions are insufficient.

## What `cloudflared.install.op` does

When it runs successfully:

1. Validates `cloudflared_tunnel_token` is present.
2. Prevents accidental use of Tunnel ID (UUID) instead of token.
3. Installs `cloudflared` from the official binary release (without apt repository dependency).
4. Reinstalls the systemd service using the official command:
	- `cloudflared service install <TOKEN>`
5. Enables and starts `cloudflared.service`.
6. Prints status and logs for quick runtime validation.

## Required parameter

Only one parameter is required:

1. `cloudflared_tunnel_token`

## Important: Tunnel Token vs Tunnel ID

`cloudflared_tunnel_token` must be the connector token (usually starts with `eyJ...`).

Do not use the tunnel UUID (Tunnel ID), for example:

```text
0cfd1079-c6b7-410e-9f81-7fa6eece936f
```

If you use Tunnel ID instead of token, the service fails with errors like:

```text
Provided Tunnel token is not valid.
```

## Installation command (local machine)

From the `ops` folder:

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

Alternative also supported by the installer:

```bash
saas source ./cloudflared.install.op \
	--node=localmaster \
	--root \
	--cloudflared_tunnel_token=CLOUDFLARE_TOKEN
```

If the token was exposed in chat, logs, or screenshots, rotate it in Cloudflare and rerun the installer with the new token.

## How to get `cloudflared_tunnel_token`

1. Open Cloudflare Zero Trust.
2. Go to Networks -> Tunnels.
3. Open your tunnel.
4. Open **Install and run connectors**.
5. Copy the token from the command shown by Cloudflare.

## SSH route setup in Cloudflare (dashboard)

After the connector is active:

1. Go to Networks -> Tunnels -> your tunnel.
2. Open **Published application routes**.
3. Create a route:
	- Subdomain: `dev2` (or any name you want)
	- Domain: your zone (example: `connectionsphere.com`)
	- Type: `SSH`
	- URL: `localhost:22`
4. Leave Path empty for SSH.

Expected result: a public hostname such as `dev2.connectionsphere.com`, routed through the tunnel to `ssh://localhost:22`.

## Service control operations

Start service:

```bash
saas source ./cloudflared.start.op --node=localmaster --root
```

Stop service:

```bash
saas source ./cloudflared.stop.op --node=localmaster --root
```

## Validation

Useful checks on the local server:

```bash
systemctl is-active cloudflared
systemctl --no-pager --full status cloudflared
journalctl -u cloudflared -n 120 --no-pager
```

Healthy logs usually include messages like:

```text
Registered tunnel connection ... protocol=quic
```

## Troubleshooting

1. `Provided Tunnel token is not valid`
	- Recopy the token from **Install and run connectors**.
	- Verify it is a token (`eyJ...`) and not a Tunnel ID (UUID).
	- Reinstall with `cloudflared.install.op`.

2. Service keeps restarting
	- Check logs: `journalctl -u cloudflared -n 120 --no-pager`.
	- Run `cloudflared.install.op` again to reinstall the service with a valid token.

3. Hostname is not reachable
	- Confirm the route exists in **Published application routes**.
	- Confirm route type is `SSH` and target is `localhost:22`.
	- Confirm local SSH is listening on port 22.

4. Domain dropdown shows `No valid options`
	- Make sure you are in the correct Cloudflare account.
	- Add or delegate a DNS zone to that account.
	- Confirm your user has DNS and Tunnel permissions.
