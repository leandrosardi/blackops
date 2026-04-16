# Ollama Server Installer

This document explains the operation `ai.install.op`.

The operation provisions an AI server on Ubuntu, installs Ollama, pulls a default model, runs Open WebUI in Docker, and exposes a protected HTTP endpoint for Ollama API calls through Nginx.

## What `ai.install.op` does

When executed successfully, it performs the following tasks:

1. Ensures the target user (`$$ssh_username`) exists and owns its home folder.
2. Updates the OS packages.
3. Installs required software: `curl`, `docker.io`, `nginx`, `git`, `ufw`.
4. Installs and starts Ollama.
5. Configures Ollama service overrides:
	- `OLLAMA_NUM_THREADS=$(nproc)`
	- `OLLAMA_KEEP_ALIVE=5m`
	- `OLLAMA_MAX_LOADED_MODELS=1`
6. Pulls model `phi3:mini`.
7. Runs Open WebUI container on port `3000` using host networking.
8. Configures Nginx to proxy `/ollama/` to `127.0.0.1:11434`.
9. Protects `/ollama/` with `Authorization: Bearer <ai_api_key>`.
10. Opens firewall ports `22`, `80`, and `3000`.

## Required parameters

The operation references these variables, so they must be available from node config or CLI parameters:

1. `ssh_username`: Linux user that will own `/home/<user>`.
2. `ai_api_key`: Bearer token expected by Nginx for `/ollama/` requests.

If `ai_api_key` is missing, `saas` will fail before execution with a "missing parameters" error.

## Example command

From the `ops` folder:

```bash
saas source ./ai.install.op --node=localmaster --root --ai_api_key=CHANGE_ME_TO_A_LONG_RANDOM_SECRET
```

If `ssh_username` is not already defined in your node descriptor, pass it explicitly:

```bash
saas source ./ai.install.op --node=localmaster --root --ssh_username=leandro --ai_api_key=CHANGE_ME_TO_A_LONG_RANDOM_SECRET
```

## How to generate `ai_api_key`

Use a long random value (at least 32 characters). Example:

```bash
openssl rand -hex 32
```

Then pass the generated string in `--ai_api_key=<value>`.

## Endpoints after installation

1. Open WebUI:
	- `http://<server-ip>:3000`
2. Ollama API (behind Nginx auth):
	- `http://<server-ip>/ollama/api/generate`

Example API request:

```bash
curl http://<server-ip>/ollama/api/generate \
  -H "Authorization: Bearer <ai_api_key>" \
  -H "Content-Type: application/json" \
  -d '{"model":"phi3:mini","prompt":"Write a cold email"}'
```

## Validation checklist

Run these checks on the target server:

```bash
systemctl status ollama --no-pager
docker ps | grep open-webui
nginx -t
curl -s http://127.0.0.1:11434/api/tags
```

Test authenticated proxy:

```bash
curl -i http://127.0.0.1/ollama/api/tags -H "Authorization: Bearer <ai_api_key>"
```

## Notes and limitations

1. The script uses `--network=host` for Open WebUI.
2. UFW is forcibly enabled; ensure this matches your server policy.
3. The default model is `phi3:mini`; downloading may take time depending on network speed.
4. The operation is intended for root execution (`--root`).

## Troubleshooting

1. `Missing parameters required by the op ... ai_api_key`:
	- Add `--ai_api_key=<value>` or define `:ai_api_key` in the node.
2. `docker` errors:
	- Confirm Docker service is running: `systemctl status docker`.
3. `ollama` not responding:
	- Check logs: `journalctl -u ollama -n 100 --no-pager`.
4. Unauthorized API responses:
	- Ensure header format is exactly `Authorization: Bearer <ai_api_key>`.
