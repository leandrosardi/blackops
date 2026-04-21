# Cloudflared

This document explains the operations `cloudflared.install.op`, `cloudflared.start.op`, and `cloudflared.stop.op`.

The installer provisions Cloudflare Tunnel on Ubuntu, creates a `cloudflared` systemd service, and configures ingress routes for SSH, HTTP, and HTTPS.

## What `cloudflared.install.op` does

When executed successfully, it performs the following tasks:

1. Validates required parameters exist.
2. Installs `cloudflared` binary from official Cloudflare releases.
3. Stores tunnel token at `/etc/cloudflared/tunnel-token`.
4. Writes `/etc/cloudflared/config.yml` with ingress rules:
	- `ssh://localhost:22`
	- `http://localhost:80`
	- `https://localhost:443` (with `noTLSVerify: true`)
5. Creates/updates `/etc/systemd/system/cloudflared.service`.
6. Enables and restarts the `cloudflared` service.
7. Prints status and logs for runtime validation.

## Required parameters

The operation references these variables, so they must be available from node config or CLI parameters:

1. `cloudflared_tunnel_token`
2. `cloudflared_ssh_hostname`
3. `cloudflared_http_hostname`
4. `cloudflared_https_hostname`

If any of them is missing, `saas` will fail before or during execution.

## Important: Tunnel Token vs Tunnel ID

`cloudflared_tunnel_token` must be the connector token (usually starts with `eyJ...`).

Do not use the tunnel UUID shown as Tunnel ID (example: `0cfd1079-c6b7-410e-9f81-7fa6eece936f`).

If you use Tunnel ID instead of token, the service will fail with:

```
Provided Tunnel token is not valid.
```

## Example command

From the `ops` folder:

```bash
saas source ./cloudflared.install.op \
  --node=localmaster \
  --root \
  --cloudflared_tunnel_token=YOUR_CONNECTOR_TOKEN \
  --cloudflared_ssh_hostname=ssh.example.com \
  --cloudflared_http_hostname=app.example.com \
  --cloudflared_https_hostname=secure.example.com
```

## How to get `cloudflared_tunnel_token`

1. Open Cloudflare Zero Trust dashboard.
2. Go to Networks -> Tunnels.
3. Open your tunnel.
4. Open Connectors.
5. Copy the token shown in "Install and run a connector" (`cloudflared tunnel run --token ...`).

If token is exposed or old, use "Refresh token" in the same screen and re-run installer.

## Start and stop operations

Start service:

```bash
saas source ./cloudflared.start.op --node=localmaster --root
```

Stop service:

```bash
saas source ./cloudflared.stop.op --node=localmaster --root
```

## Validation checklist

Run these checks on the target server:

```bash
systemctl is-active cloudflared
systemctl --no-pager --full status cloudflared
journalctl -u cloudflared -n 120 --no-pager
```

Expected healthy logs include messages like:

```
Registered tunnel connection ... protocol=quic
```

## Troubleshooting

1. `Provided Tunnel token is not valid`:
	- Re-copy token from Connectors page.
	- Ensure value is token (`eyJ...`), not tunnel UUID.
	- Re-run `cloudflared.install.op` with new token.

2. Service keeps restarting:
	- Check logs: `journalctl -u cloudflared -n 120 --no-pager`.
	- Verify token file: `sudo cat /etc/cloudflared/tunnel-token`.

3. Hostnames not reachable:
	- Confirm public hostnames are mapped in Cloudflare tunnel routes.
	- Confirm local services are listening on ports 22, 80, and 443.

4. Installer cannot use apt repositories:
	- Current operation uses direct binary download, so apt mirror issues should not block installation.
