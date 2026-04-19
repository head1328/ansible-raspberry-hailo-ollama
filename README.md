# Ansible Role: Hailo Ollama LLM Server

Installs and configures the Hailo Ollama LLM server for
the Hailo-10H NPU (AI HAT+ 2) on Raspberry Pi 5, with
Open WebUI chat frontend and optional Caddy reverse proxy
with TLS (both containerized via Podman Quadlets).

## Requirements

- Raspberry Pi 5
- Debian Trixie (64-bit)
- AI HAT+ 2 (Hailo-10H) physically installed
- Role dependency: `head1328.hailo`
- Optional (for Caddy/WebUI): `head1328.podman`
  and `containers.podman` collection

## Installation

```bash
ansible-galaxy role install head1328.hailo_ollama
```

## Usage

### Basic (no proxy, no WebUI)

```yaml
- name: Setup Hailo Ollama server
  hosts: ai_nodes
  become: true
  roles:
    - role: head1328.hailo_ollama
      hailo_ollama_webui_enabled: false
```

This exposes hailo-ollama directly on port 8000.

### With Caddy and Open WebUI (recommended)

```yaml
- name: Setup Hailo Ollama with Caddy and Open WebUI
  hosts: ai_nodes
  become: true
  roles:
    - role: head1328.podman
    - role: head1328.hailo_ollama
      hailo_ollama_caddy_enabled: true
      hailo_ollama_caddy_fqdn: my-pi5.fritz.box
      hailo_ollama_caddy_podman_user: podman
      hailo_ollama_webui_podman_user: podman
```

This deploys:

- hailo-ollama on port 8000 (loopback only)
- Open WebUI on port 3000 (loopback only)
- Caddy on port 443 with TLS (reverse proxy)
- iptables PREROUTING redirect from 443 to 8443
  (rootless Podman cannot bind privileged ports)
- iptables INPUT rules restricting backend ports
  to loopback only

All traffic goes through Caddy via HTTPS. Open WebUI
is the default frontend, the API is available under
`/ollama/`.

## Architecture

### With Caddy (recommended)

```
Browser
  |
  v
https://<fqdn>
  |  (iptables PREROUTING redirect 443 -> 8443)
  v
Caddy (TLS, Podman Quadlet, :8443)
  |
  +-- /              --> Open WebUI :3000
  +-- /ollama/*      --> hailo-ollama :8000
  |
  v
iptables: ports 8000 + 3000 loopback only
  |
  v
hailo-ollama (systemd) --> Hailo-10H NPU
```

### Without Caddy

```
Browser/Client
  |
  +-- http://<host>:3000 --> Open WebUI (Podman)
  +-- http://<host>:8000 --> hailo-ollama (systemd)
                               |
                               v
                          Hailo-10H NPU
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `hailo_ollama_version` | `5.1.1` | GenAI Model Zoo version |
| `hailo_ollama_deb_url` | (auto) | Download URL for the deb |
| `hailo_ollama_host` | `0.0.0.0` | Listen address |
| `hailo_ollama_port` | `8000` | Listen port |
| `hailo_ollama_service_enabled` | `true` | Enable systemd service |
| `hailo_ollama_caddy_enabled` | `false` | Deploy Caddy with TLS |
| `hailo_ollama_caddy_fqdn` | `ollama.local` | FQDN for TLS cert |
| `hailo_ollama_caddy_port` | `443` | External HTTPS port |
| `hailo_ollama_caddy_internal_port` | `8443` | Internal Caddy port |
| `hailo_ollama_caddy_port_redirect` | `true` | iptables redirect |
| `hailo_ollama_caddy_podman_user` | `podman` | Caddy container user |
| `hailo_ollama_caddy_firewall` | `true` | Manage iptables rules |
| `hailo_ollama_webui_enabled` | `true` | Deploy Open WebUI |
| `hailo_ollama_webui_port` | `3000` | WebUI port |
| `hailo_ollama_webui_image` | `...open-webui:0.8` | WebUI image |
| `hailo_ollama_webui_podman_user` | `podman` | WebUI container user |

When `hailo_ollama_caddy_port` is < 1024 and
`hailo_ollama_caddy_port_redirect` is `true`, an iptables
PREROUTING REDIRECT rule is created automatically. Set it
to `false` if you handle port redirection externally.

When `hailo_ollama_caddy_port` is >= 1024 (e.g. 8443),
no redirect is needed and Caddy binds directly.

Set `hailo_ollama_caddy_firewall` to `false` if you
manage INPUT firewall rules externally.

## After Installation

### Open WebUI

When Caddy is enabled, open `https://<fqdn>` in your
browser. On first launch you will be prompted to create
an admin account.

When Caddy is not enabled, Open WebUI is available at
`http://<hostname>:3000`.

Caddy uses an internal CA for TLS. To avoid browser
warnings, export and trust the root CA certificate:

```bash
# On the Pi: export from container
sudo su - podman -s /bin/bash -c \
  'podman cp hailo-ollama-caddy:/data/caddy/pki/authorities/local/root.crt \
  /tmp/caddy-root-ca.crt'
sudo mv /tmp/caddy-root-ca.crt /home/$USER/caddy-root-ca.crt
sudo chown $USER:$USER /home/$USER/caddy-root-ca.crt

# On your machine: copy and install
scp <hostname>:~/caddy-root-ca.crt .

# macOS: add to keychain
open caddy-root-ca.crt
```

In Keychain Access, double-click the "Caddy Local
Authority" certificate, expand "Trust", and set "When
using this certificate" to "Always Trust".

### Pull a model

Models must be pulled before they can be used. Pull via
CLI (Open WebUI model pull is not supported, see
compatibility section below):

```bash
curl -k https://<fqdn>/ollama/api/pull \
  -H 'Content-Type: application/json' \
  -d '{"model": "qwen2:1.5b", "stream": true}'
```

```json
{"status":"success"}
```

Without Caddy:

```bash
curl http://<hostname>:8000/api/pull \
  -H 'Content-Type: application/json' \
  -d '{"model": "qwen2:1.5b", "stream": true}'
```

### Chat via API

```bash
curl -k https://<fqdn>/ollama/api/chat \
  -H 'Content-Type: application/json' \
  -d '{"model": "qwen2:1.5b", "messages": [
    {"role": "user", "content": "What is 2+2?"}
  ]}'
```

```json
{
  "model": "qwen2:1.5b",
  "message": {
    "role": "assistant",
    "content": "The sum of two is four: 2 + 2 = 4"
  },
  "done": true,
  "total_duration": 2167540741,
  "eval_count": 15
}
```

### Direct API access

When Caddy is enabled, the API is under `/ollama/`:

```bash
curl -k https://<fqdn>/ollama/hailo/v1/list
curl -k https://<fqdn>/ollama/api/tags
```

Without Caddy:

```bash
curl http://<hostname>:8000/hailo/v1/list
curl http://<hostname>:8000/api/tags
```

## Open WebUI Compatibility

Open WebUI 0.8 calls non-standard Ollama API endpoints
(e.g. `/api/tags/0`, `/config`) and uses different field
names in some requests. Caddy includes URL rewrites and
stubs to work around these incompatibilities.

### Workarounds applied by Caddy

- `/config` stubbed with empty JSON response
- `/api/<endpoint>/0` rewritten to `/api/<endpoint>`
  (Open WebUI appends a connection index)

### What works in Open WebUI

- Chat with loaded models
- Model list and details
- Connections settings page
- Model selection

### Important: Single model at a time

hailo-ollama can only load one model on the NPU at a time.
Switching models takes ~20 seconds. If Open WebUI has
multiple chat conversations open with different models,
hailo-ollama will constantly swap between them, causing
very slow responses. Stick to one model or delete old
conversations that use a different model.

### Background tasks disabled

Open WebUI's automatic title generation and follow-up
suggestion features are disabled by default in this role.
These background tasks send additional requests to
hailo-ollama after every chat message, which can block
the generation thread and cause timeouts. The NPU can
only process one request at a time.

To re-enable, set the environment variables
`ENABLE_TITLE_GENERATION` and `ENABLE_FOLLOW_UP_GENERATION`
to `true` in the Open WebUI container or via the admin UI.

### What does not work

- Model pull via Open WebUI (sends `"name"` field,
  hailo-ollama expects `"model"`)
- OpenAI API connections (not applicable)
- Ollama model delete (not supported by hailo-ollama)

Future versions of Open WebUI may fix these issues or
introduce new ones. The `hailo_ollama_webui_image` is
pinned to `0.8` to avoid breaking changes.

## Installation Sources

Two installation paths are available, controlled by
`hailo_ollama_source` (and `hailo_source` in the
`head1328.hailo` role):

| | `raspberry` (default) | `vendor` |
|---|---|---|
| Runtime | `h10-hailort` 5.1.1 (Raspi repo) | `hailort` 5.3.0 (hailo.ai) |
| PCIe driver | `h10-hailort-pcie-driver` 5.1.1 | `hailort-pcie-driver` 5.3.0 |
| GenAI Model Zoo | 5.1.1 | 5.3.0 |
| Source | Raspberry Pi apt repo | dev-public.hailo.ai |
| Models | 5 (max 3B) | 6 (incl. qwen3:1.7b) |

Both sources must match across `head1328.hailo` and
`head1328.hailo_ollama`. Do not mix raspberry runtime
with vendor model zoo or vice versa.

**Switching between sources requires a reboot** (PCIe
driver change) and **all pulled models will be lost**.
Models must be re-pulled after switching. Open WebUI
data (accounts, chats) is preserved in the Podman volume.

## Available Models

### Raspberry (5.1.1)

- `deepseek_r1_distill_qwen:1.5b`
- `llama3.2:3b`
- `qwen2:1.5b`
- `qwen2.5-coder:1.5b`
- `qwen2.5-instruct:1.5b`

### Vendor (5.3.0)

- `deepseek_r1:1.5b`
- `llama3.2:1b`
- `qwen2:1.5b`
- `qwen2.5:1.5b`
- `qwen2.5-coder:1.5b`
- `qwen3:1.7b`

## Local Development

Symlink the role into your local Ansible roles path for
development without reinstalling:

```bash
make symlink
```

This creates a symlink at
`~/.ansible/roles/head1328.hailo_ollama` pointing to the
working directory. Changes are immediately available to
playbooks.

## Testing

Tests require a Raspberry Pi with Hailo-10H hardware.
The target host is configured via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `MOLECULE_HOST` | (required) | SSH hostname of test Pi |
| `MOLECULE_USER` | `ansible` | SSH user on test Pi |

### Test Scenarios

**Full test** (installs, deploys, verifies):

```bash
MOLECULE_HOST=my-pi5 make test
```

**Simulate** (dry-run, verifies package URL):

```bash
MOLECULE_HOST=my-pi5 make test-simulate
```

**All scenarios**:

```bash
MOLECULE_HOST=my-pi5 make test-all
```

## License

AGPL-3.0-or-later
