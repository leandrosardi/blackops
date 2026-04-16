# Ngrok

The operation file `ngrok.install.op` installs ngrok v3 and can optionally configure your ngrok account token.

## Why `ngrok_authtoken` exists

`ngrok_authtoken` is your personal ngrok credential. When present, this operation runs:

```
ngrok config add-authtoken <your-token>
```

This links the local ngrok installation to your ngrok account so authenticated features can work.

## Example command

Use the command below when running against a configured node:

```
saas source ./ngrok.install.op --node=localmaster --root --ngrok_authtoken=YOUR_REAL_TOKEN
```

If you only want to install the binary now and skip account configuration, pass the parameter empty:

```
saas source ./ngrok.install.op --node=localmaster --root --ngrok_authtoken=
```

## How to generate/get the value for `ngrok_authtoken`

1. Create an account or sign in at https://dashboard.ngrok.com.
2. Open the page **Your Authtoken** in the ngrok dashboard.
3. Copy the token value shown there.
4. Use that value in `--ngrok_authtoken=<value>`.

You can validate it manually on a machine with ngrok installed:

```
ngrok config add-authtoken <value>
ngrok config check
```

## When to keep it empty

Keep `--ngrok_authtoken=` empty when:

1. You only need ngrok installed now and will configure credentials later.
2. You are preparing base images/scripts where secrets should not be stored.
3. You are testing the install workflow itself (download/extract/binary availability).

Set a real token when the machine will actually open authenticated ngrok tunnels.

## Disclaimer

BlackOps is provided “as is,” without warranty of any kind, express or implied. In no event shall the authors or contributors be liable for any claim, damages, or other liability arising from—whether in an action of contract, tort, or otherwise—your use of BlackOps or any operations performed with it. You assume full responsibility for verifying that any deployment or configuration change executed with BlackOps is safe and appropriate for your environment.

All third-party trademarks, service marks, and logos used in this README or in the tool itself remain the property of their respective owners, and no endorsement is implied. Use of BlackOps is at your own risk.

Logo has been taken from [here](https://www.flaticon.com/free-icon/command-line_9969711?related_id=9969486&origin=search).

